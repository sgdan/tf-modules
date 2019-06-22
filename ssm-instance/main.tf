data "aws_subnet_ids" "private" {
  vpc_id = var.vpc_id
  tags = {
    Tier = "private"
  }
}

# Find the latest Amazon Linux 2 AMI
data "aws_ami" "current" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "this" {
  ami                    = data.aws_ami.current.id
  instance_type          = "t2.micro"
  subnet_id              = tolist(data.aws_subnet_ids.private.ids)[0]
  vpc_security_group_ids = [aws_security_group.this.id]
  iam_instance_profile   = aws_iam_instance_profile.this.name
  tags = {
    Name = "Instance to test Session Manager"
  }
}

# Need instance profile with SSM policy
resource "aws_iam_instance_profile" "this" {
  role = aws_iam_role.this.name
}
resource "aws_iam_role" "this" {
  description        = "SSM Role"
  assume_role_policy = file("${path.module}/ssm-policy.json")
}
resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

# Need HTTP/HTTPS egress for Session Manager
resource "aws_security_group" "this" {
  vpc_id = var.vpc_id
  tags = {
    Name = "Test Instance SG"
  }
}
resource "aws_security_group_rule" "http" {
  security_group_id = aws_security_group.this.id
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "https" {
  security_group_id = aws_security_group.this.id
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}
