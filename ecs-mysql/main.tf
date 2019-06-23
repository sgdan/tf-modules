data "aws_region" "current" {}
data "aws_availability_zones" "all" {}
data "aws_caller_identity" "this" {}

data "aws_ecs_cluster" "this" {
  cluster_name = var.ecs_cluster
}

resource "aws_ecs_service" "this" {
  name            = "mysql"
  cluster         = data.aws_ecs_cluster.this.arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
}

resource "random_string" "this" {
  length  = 16
  special = false
}

resource "aws_ssm_parameter" "this" {
  name        = "/mysql/password"
  description = "Master password of MySQL database"
  type        = "SecureString"
  value       = random_string.this.result
  overwrite   = false
}

resource "aws_iam_role" "this" {
  description        = "IAM role for executing MySQL"
  assume_role_policy = file("${path.module}/assume_role_policy.json")
}

resource "aws_iam_policy" "this" {
  description = "IAM policy for MySQL container"
  policy = templatefile("${path.module}/iam_policy.json", {
    region  = data.aws_region.current.name
    account = data.aws_caller_identity.this.account_id
  })
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

resource "aws_ecs_task_definition" "this" {
  family             = "mysql"
  execution_role_arn = aws_iam_role.this.arn
  container_definitions = templatefile("${path.module}/containers.json", {
    account   = data.aws_caller_identity.this.account_id,
    region    = data.aws_region.current.name
    log_group = var.log_group
  })
  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone==${data.aws_availability_zones.all.names[0]}"
  }
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  volume {
    name = "mysql-data"
    docker_volume_configuration {
      scope         = "shared"
      autoprovision = true
      driver        = "rexray/ebs"
      driver_opts = {
        volumetype = "gp2"
        size       = 5
      }
    }
  }
}

resource "aws_cloudwatch_log_stream" "this" {
  name           = "mysql"
  log_group_name = var.log_group
}
