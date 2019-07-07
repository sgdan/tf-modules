data "aws_subnet" "private" {
  count = length(var.private_subnet_ids)
  id    = var.private_subnet_ids[count.index]
}

resource "aws_db_subnet_group" "this" {
  subnet_ids = var.private_subnet_ids
  tags = {
    Name = "Concourse subnet group"
  }
}

resource "aws_db_instance" "this" {
  allocated_storage      = 5
  max_allocated_storage  = 10
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "11.4"
  instance_class         = "db.t2.micro"
  name                   = "concourse"
  username               = "concourse"
  password               = var.password
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
}

resource "aws_security_group" "this" {
  vpc_id = var.vpc_id
  ingress {
    description = "Postgres"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = data.aws_subnet.private[*].cidr_block
  }
  tags = {
    Name = "Concourse Database"
  }
}
