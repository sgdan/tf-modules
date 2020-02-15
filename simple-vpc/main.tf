data "aws_availability_zones" "all" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.24.0"

  name                = "simple-vpc"
  cidr                = var.vpc_cidr
  azs                 = [data.aws_availability_zones.all.names[0], data.aws_availability_zones.all.names[1]]
  public_subnets      = var.public_subnet_cidrs
  private_subnets     = var.private_subnet_cidrs
  public_subnet_tags  = { Tier = "public" }
  private_subnet_tags = merge({ Tier = "private" }, var.custom_private_tags)

  vpc_tags = var.custom_vpc_tags

  # will use NAT instance instead since it's cheaper
  enable_nat_gateway = false
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
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.this.id]
  source_dest_check      = false # required to support NAT
  tags = {
    Name = "NAT instance"
  }
}

resource "aws_route" "this" {
  count                  = length(module.vpc.private_route_table_ids)
  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  instance_id            = aws_instance.this.id
}

resource "aws_security_group" "this" {
  name   = "nat-instance-sg"
  vpc_id = module.vpc.vpc_id
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
  cidr_blocks       = var.private_subnet_cidrs
}
resource "aws_security_group_rule" "https_in" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.private_subnet_cidrs
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

# Empty default sg with no ingress/egress allowed
resource "aws_default_security_group" "default" {
  vpc_id = module.vpc.vpc_id
}
