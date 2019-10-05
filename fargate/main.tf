data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_ecs_cluster" "this" {
  name = "test-cluster"
}

resource "aws_ecs_task_definition" "this" {
  family                   = "test-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.this.arn
  container_definitions = jsonencode([{
    name    = "test-container"
    image   = "alpine"
    command = ["env"]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "fargate-test"
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = "test"
      }
    }
    secrets = [{
      name      = "TEST_ENV"
      valueFrom = "fargate-test-param"
    }]
  }])
}

resource "aws_cloudwatch_log_group" "this" {
  name = "fargate-test"
}

resource "aws_security_group" "this" {
  description = "Test Fargate SG"
  vpc_id      = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "this" {
  description = "Fargate task execution role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy" "this" {
  name = "fargate-execution-policy"
  role = aws_iam_role.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = "ssm:GetParameters"
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/fargate-test-param"
      }
    ]
  })
}

resource "aws_ssm_parameter" "this" {
  type      = "SecureString"
  name      = "fargate-test-param"
  value     = "fargate-test-value"
  overwrite = true
}
