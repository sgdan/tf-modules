locals {
  name = "concourse-worker"
}

data "aws_region" "current" {}

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
  family                   = local.name
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  container_definitions = templatefile("${path.module}/containers.json", {
    region = data.aws_region.current.name
    name   = local.name
  })
}

resource "aws_cloudwatch_log_group" "this" {
  name = local.name
}
