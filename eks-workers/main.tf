data "aws_region" "current" {}
data "aws_availability_zones" "all" {}

data "aws_subnet_ids" "private" {
  vpc_id = var.vpc_id
  tags   = { Tier = "private" }
}
data "aws_subnet_ids" "public" {
  vpc_id = var.vpc_id
  tags   = { Tier = "public" }
}

data "aws_eks_cluster" "this" {
  name = var.name
}

data "aws_ami" "this" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${data.aws_eks_cluster.this.version}-v*"]
  }
  most_recent = true
  owners      = ["amazon"]
}

resource "aws_iam_role" "this" {
  name        = "eks-${var.name}-worker-role"
  description = "Worker role for eks ${var.name} cluster"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.this.name
}
resource "aws_iam_role_policy_attachment" "cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.this.name
}
resource "aws_iam_role_policy_attachment" "ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.this.name
}
resource "aws_iam_role_policy_attachment" "ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.this.name
}

resource "aws_iam_instance_profile" "this" {
  name = "eks-${var.name}-instance-profile"
  role = aws_iam_role.this.name
}

resource "aws_launch_template" "this" {
  name          = "eks-${var.name}-worker-template"
  image_id      = data.aws_ami.this.id
  instance_type = var.instance_types[0]
  iam_instance_profile {
    name = aws_iam_instance_profile.this.name
  }
  vpc_security_group_ids = [var.worker_sg_id]
  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    ClusterName = var.name
  }))
}

resource "aws_autoscaling_group" "this" {
  name             = "eks-${var.name}-worker-group"
  desired_capacity = 2
  max_size         = 2
  min_size         = 2
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.this.id
        version            = "$Latest"
      }
      dynamic "override" {
        for_each = var.instance_types
        content {
          instance_type = override.value
        }
      }
    }
    instances_distribution {
      # 100% spot
      on_demand_percentage_above_base_capacity = 0
    }
  }
  vpc_zone_identifier = tolist(data.aws_subnet_ids.private.ids)
  target_group_arns   = [aws_lb_target_group.this.arn]
  tag {
    key                 = "kubernetes.io/cluster/${var.name}"
    value               = "owned"
    propagate_at_launch = true
  }
  tag {
    key                 = "Name"
    value               = "eks-${var.name}-worker-group"
    propagate_at_launch = true
  }
}

# ALB for connections from internet
resource "aws_lb" "this" {
  name               = "eks-${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.public.ids
  security_groups    = [aws_security_group.alb.id]
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
resource "aws_lb_target_group" "this" {
  name     = "eks-${var.name}-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    path    = "/healthz" # for nginx ingress controller
    matcher = "200"
  }
}

# Security group for ALB
resource "aws_security_group" "alb" {
  name        = "eks-${var.name}-alb-sg"
  description = "ALB SG for eks ${var.name}"
  vpc_id      = var.vpc_id
  tags        = { Name = "eks-${var.name}-alb-sg" }
}
locals {
  rules = {
    https         = ["ingress", "tcp", 443, aws_security_group.alb.id, null, var.cidrs, "HTTPS"]
    http          = ["ingress", "tcp", 80, aws_security_group.alb.id, null, var.cidrs, "HTTP"]
    out           = ["egress", "tcp", 80, aws_security_group.alb.id, var.worker_sg_id, null, "ALB to workers"]
    health-checks = ["ingress", "tcp", 80, var.worker_sg_id, aws_security_group.alb.id, null, "Workers from ALB"]
  }
}
resource "aws_security_group_rule" "this" {
  for_each                 = local.rules
  type                     = each.value[0]
  protocol                 = each.value[1]
  from_port                = each.value[2]
  to_port                  = each.value[2]
  security_group_id        = each.value[3]
  source_security_group_id = each.value[4]
  cidr_blocks              = each.value[5]
  description              = each.value[6]
}

data "aws_route53_zone" "this" {
  name = "${var.domain}."
}
resource "aws_route53_record" "this" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "${var.prefix}.${var.domain}"
  type    = "A"
  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}
