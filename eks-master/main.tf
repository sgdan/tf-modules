data "aws_subnet_ids" "private" {
  vpc_id = var.vpc_id
  tags = {
    Tier = "private"
  }
}

resource "aws_eks_cluster" "this" {
  name     = var.name
  role_arn = aws_iam_role.this.arn
  vpc_config {
    subnet_ids         = data.aws_subnet_ids.private.ids
    security_group_ids = [aws_security_group.master.id]
  }
}

resource "aws_iam_role" "this" {
  description        = "Service role for eks ${var.name} cluster"
  assume_role_policy = file("${path.module}/role_policy.json")
}

resource "aws_iam_role_policy_attachment" "cluster" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.this.name
}

resource "aws_iam_role_policy_attachment" "service" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.this.name
}

resource "aws_security_group" "master" {
  name        = "eks-${var.name}-master-sg"
  description = "Control plane SG for eks ${var.name}"
  vpc_id      = var.vpc_id
  tags = {
    Name = "eks-${var.name}-master-sg"
  }
}

resource "aws_security_group" "workers" {
  name        = "eks-${var.name}-workers-sg"
  description = "Worker SG for eks ${var.name}"
  vpc_id      = var.vpc_id
  tags = {
    Name = "eks-${var.name}-workers-sg"
  }
}

resource "aws_security_group_rule" "master-from-workers" {
  description              = "HTTPS to control plane from workers"
  security_group_id        = aws_security_group.master.id
  source_security_group_id = aws_security_group.workers.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
}
resource "aws_security_group_rule" "master-to-workers" {
  description              = "Range from control plane to workers"
  security_group_id        = aws_security_group.master.id
  source_security_group_id = aws_security_group.workers.id
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = 1025
  to_port                  = 65535
}

resource "aws_security_group_rule" "workers-from-master-https" {
  description              = "HTTPS to workers from control plane"
  security_group_id        = aws_security_group.workers.id
  source_security_group_id = aws_security_group.master.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
}
resource "aws_security_group_rule" "workers-from-master-range" {
  description              = "Range to workers from control plane"
  security_group_id        = aws_security_group.workers.id
  source_security_group_id = aws_security_group.master.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 1025
  to_port                  = 65535
}

resource "aws_security_group_rule" "workers-from-workers" {
  description              = "All traffic between workers"
  security_group_id        = aws_security_group.workers.id
  source_security_group_id = aws_security_group.workers.id
  type                     = "ingress"
  protocol                 = "-1"
  from_port                = 0
  to_port                  = 0
}

resource "aws_security_group_rule" "workers-to-anywhere" {
  description       = "All outgoing traffic from workers"
  security_group_id = aws_security_group.workers.id
  cidr_blocks       = ["0.0.0.0/0"]
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
}
