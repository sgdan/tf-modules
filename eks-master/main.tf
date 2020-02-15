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
  name        = "eks-${var.name}-master-role"
  description = "Service role for eks ${var.name} cluster"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
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

locals {
  rules = {
    master-in  = ["ingress", "tcp", 443, 443, aws_security_group.master.id, aws_security_group.workers.id, null, "HTTPS to control plane from workers"]
    master-out = ["egress", "tcp", 1025, 65535, aws_security_group.master.id, aws_security_group.workers.id, null, "Range from control plane to workers"]
    https-in   = ["ingress", "tcp", 443, 443, aws_security_group.workers.id, aws_security_group.master.id, null, "HTTPS to workers from control plane"]
    range-in   = ["ingress", "tcp", 1025, 65535, aws_security_group.workers.id, aws_security_group.master.id, null, "Range to workers from control plane"]
    cluster    = ["ingress", "-1", 0, 0, aws_security_group.workers.id, aws_security_group.workers.id, null, "All traffic between workers"]
    out        = ["egress", "-1", 0, 0, aws_security_group.workers.id, null, ["0.0.0.0/0"], "All outgoing traffic from workers"]
  }
}

resource "aws_security_group_rule" "this" {
  for_each                 = local.rules
  type                     = each.value[0]
  protocol                 = each.value[1]
  from_port                = each.value[2]
  to_port                  = each.value[3]
  security_group_id        = each.value[4]
  source_security_group_id = each.value[5]
  cidr_blocks              = each.value[6]
  description              = each.value[7]
}
