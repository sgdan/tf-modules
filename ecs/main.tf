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
  vpc_security_group_ids               = [aws_security_group.this.id]

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
  health_check_grace_period = 30
  default_cooldown          = 30

  # Only use 1 AZ so that it's easy to use EBS volumes
  vpc_zone_identifier = [var.subnet_ids[0]]

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

# HTTP/HTTPS access required for session manager
resource "aws_security_group" "this" {
  vpc_id = var.vpc_id
  tags = {
    Name = "HTTPS out to internet"
  }
}
resource "aws_security_group_rule" "https" {
  security_group_id = aws_security_group.this.id
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "http" {
  security_group_id = aws_security_group.this.id
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

# IAM role for ECS nodes
resource "aws_iam_instance_profile" "this" {
  role = aws_iam_role.this.name
}

data "local_file" "policy" {
  filename = "${path.module}/ecs-policy.json"
}

resource "aws_iam_role" "this" {
  description        = "ECS Role"
  assume_role_policy = data.local_file.policy.content
}

resource "aws_iam_role_policy" "rexray" {
  name   = "rexray-policy-for-ecs"
  role   = aws_iam_role.this.id
  policy = file("${path.module}/rexray-policy.json")
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_iam_role_policy_attachment" "ecs" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "cwlogs" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_cloudwatch_log_group" "this" {
  name = "/ecs/tasks"
}
