# Find the latest Ubuntu image
data "aws_ami" "this" {
  owners      = ["099720109477"] # Canonical
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
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
  ami                    = data.aws_ami.this.id
  instance_type          = "t3a.medium"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.this.id]
  iam_instance_profile   = aws_iam_instance_profile.this.name
  user_data              = file("${path.module}/userdata.sh")
  key_name               = aws_key_pair.this.key_name
  root_block_device {
    encrypted = true
  }
  tags = {
    Name = "Linux Desktop"
  }
}

resource "aws_key_pair" "this" {
  public_key = var.public_key
}

# Need instance profile with SSM policy
resource "aws_iam_instance_profile" "this" {
  role = aws_iam_role.this.name
}
resource "aws_iam_role" "this" {
  description        = "Linux Desktop Role"
  assume_role_policy = file("${path.module}/assume_role_policy.json")
}

# Need SSH in and HTTP/HTTPS out
resource "aws_security_group" "this" {
  vpc_id = var.vpc_id
  tags = {
    Name = "Desktop SG"
  }
}
resource "aws_security_group_rule" "ssh" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
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
resource "aws_security_group_rule" "https" {
  security_group_id = aws_security_group.this.id
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

data "aws_route53_zone" "this" {
  name         = "${var.domain}."
}
resource "aws_route53_record" "external" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "${var.prefix}.${var.domain}"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.this.public_ip]
}
resource "aws_route53_record" "internal" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "${var.internal_prefix}.${var.domain}"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.this.private_ip]
}
