data "aws_subnet_ids" "public" {
  vpc_id = var.vpc_id
  tags = {
    Tier = "public"
  }
}

data "aws_subnet_ids" "private" {
  vpc_id = var.vpc_id
  tags = {
    Tier = "private"
  }
}

locals {
  num_private_subnets = length(data.aws_subnet_ids.private.ids)
  private_subnet_ids  = tolist(data.aws_subnet_ids.private.ids)
}

data "aws_subnet" "private" {
  count = local.num_private_subnets
  id    = local.private_subnet_ids[count.index]
}

data "aws_route_table" "private" {
  count     = local.num_private_subnets
  subnet_id = local.private_subnet_ids[count.index]
}

# Find the latest NAT instance AMI
data "aws_ami" "current" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-vpc-nat-*"]
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
  subnet_id              = tolist(data.aws_subnet_ids.public.ids)[0]
  vpc_security_group_ids = [aws_security_group.this.id]
  source_dest_check      = false # required to support NAT
  tags = {
    Name = "NAT instance"
  }
}

resource "aws_route" "this" {
  count                  = local.num_private_subnets
  route_table_id         = data.aws_route_table.private.*.id[count.index]
  destination_cidr_block = "0.0.0.0/0"
  instance_id            = aws_instance.this.id
}

resource "aws_security_group" "this" {
  vpc_id = var.vpc_id
  tags = {
    Name = "NAT Instance SG"
  }
}

resource "aws_security_group_rule" "http_in" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = data.aws_subnet.private.*.cidr_block
}
resource "aws_security_group_rule" "https_in" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = data.aws_subnet.private.*.cidr_block
}

resource "aws_security_group_rule" "http_out" {
  security_group_id = aws_security_group.this.id
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "https_out" {
  security_group_id = aws_security_group.this.id
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}
