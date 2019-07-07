locals {
  name = "traefik"
}

data "aws_region" "current" {}

resource "aws_ecs_cluster" "this" {
  name = var.name
}

# Find the latest ECS instance AMI
data "aws_ami" "current" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_launch_template" "this" {
  name                                 = "${var.name}_ecs_template"
  description                          = "Launch template for ${var.name} ECS cluster"
  image_id                             = data.aws_ami.current.image_id # amzn2-ami-ecs-hvm-*
  instance_type                        = "t2.micro"
  instance_initiated_shutdown_behavior = "terminate"
  vpc_security_group_ids               = [aws_security_group.nodes.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.this.name
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.name}_ecs_node"
    }
  }
  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    name   = var.name
    region = data.aws_region.current.name
  }))
}

resource "aws_autoscaling_group" "this" {
  name                      = "${var.name}_ecs_nodes"
  max_size                  = 2
  min_size                  = 2
  desired_capacity          = 2
  health_check_grace_period = 0
  default_cooldown          = 0

  # Only use 1 AZ so that it's easy to use EBS volumes
  vpc_zone_identifier = [var.private_subnet_ids[0]]

  mixed_instances_policy {
    instances_distribution {
      on_demand_percentage_above_base_capacity = 0
      spot_instance_pools                      = 10
    }
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.this.id
        version            = "$Latest"
      }
      override {
        instance_type = "t2.small"
      }
      override {
        instance_type = "t3.small"
      }
    }
  }
}

resource "aws_security_group" "alb" {
  vpc_id = var.vpc_id
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.internet_whitelist]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.internet_whitelist]
  }
  egress {
    description = "Allow all"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "ALB"
  }
}

resource "aws_security_group" "traefik" {
  vpc_id = var.vpc_id
  ingress {
    description     = "From ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    description = "Allow all"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Traefik"
  }
}

resource "aws_security_group" "nodes" {
  vpc_id = var.vpc_id
  ingress {
    description     = "From Traefik"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.traefik.id]
  }
  ingress {
    description = "From other nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }
  egress {
    description = "Allow all"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "ECS Nodes"
  }
}

# IAM role for ECS nodes
resource "aws_iam_instance_profile" "this" {
  role = aws_iam_role.ecs.name
}
resource "aws_iam_role" "ecs" {
  description        = "ECS Instance Role"
  assume_role_policy = file("${path.module}/ecs-policy.json")
}
resource "aws_iam_role_policy" "rexray" {
  name   = "rexray-policy-for-ecs"
  role   = aws_iam_role.ecs.id
  policy = file("${path.module}/rexray-policy.json")
}
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ecs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}
resource "aws_iam_role_policy_attachment" "ecs" {
  role       = aws_iam_role.ecs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}
resource "aws_iam_role_policy_attachment" "cwlogs" {
  role       = aws_iam_role.ecs.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_cloudwatch_log_group" "this" {
  name = local.log_group
}

# ALB for connections from internet
resource "aws_lb" "this" {
  name_prefix        = "ecs-"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups = [
    aws_security_group.alb.id
  ]
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
  name_prefix          = "ecs-"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = 5
  health_check {
    path    = "/ping" # for Traefik ping configuration
    matcher = "200"   # can use 404 with / path if no ping configured
  }
}

# Traefik service for reverse proxying to other services
resource "aws_ecs_service" "this" {
  name            = local.name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = local.name
    container_port   = 80
  }
  network_configuration {
    subnets         = [var.private_subnet_ids[0]]
    security_groups = [aws_security_group.traefik.id]
  }

  depends_on = [aws_lb.this] # avoid error that target group has no lb
}

# Traefik task
resource "aws_iam_role" "task" {
  description        = "Traefik Task Role"
  assume_role_policy = file("${path.module}/task-assume-policy.json")
}
resource "aws_iam_role_policy" "task" {
  name   = "task-policy"
  role   = aws_iam_role.task.id
  policy = file("${path.module}/task-policy.json")
}
resource "aws_ecs_task_definition" "this" {
  family                   = local.name
  task_role_arn            = aws_iam_role.task.arn
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  container_definitions = templatefile("${path.module}/traefik-containers.json", {
    region    = data.aws_region.current.name
    name      = local.name
    domain    = var.domain
    whitelist = var.internet_whitelist
  })
}

# DNS record to point to ALB
data "aws_route53_zone" "this" {
  name         = "${var.domain}."
  private_zone = false
}
resource "aws_route53_record" "this" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "*.${data.aws_route53_zone.this.name}"
  type    = "A"
  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}
