data "aws_region" "current" {}
data "aws_availability_zones" "all" {}

data "aws_subnet_ids" "private" {
  vpc_id = var.vpc_id
  tags = {
    Tier = "private"
  }
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
  description        = "Instance role for eks ${var.name} cluster"
  assume_role_policy = file("${path.module}/role_policy.json")
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
