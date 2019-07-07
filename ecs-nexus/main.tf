locals {
  name = "nexus3"
}

data "aws_region" "current" {}
data "aws_availability_zones" "all" {}

data "aws_ecs_cluster" "this" {
  cluster_name = var.ecs_cluster
}

resource "aws_ecs_service" "this" {
  name            = local.name
  cluster         = data.aws_ecs_cluster.this.arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
}

resource "aws_ecs_task_definition" "this" {
  family = local.name
  container_definitions = templatefile("${path.module}/containers.json", {
    region = data.aws_region.current.name
    name   = local.name
    domain = var.domain
  })
  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone==${data.aws_availability_zones.all.names[0]}"
  }
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  volume {
    name = "nexus-data"
    docker_volume_configuration {
      scope         = "shared"
      autoprovision = true
      driver        = "rexray/ebs"
      driver_opts = {
        volumetype = "gp2"
        size       = 15
      }
    }
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name = local.name
}
