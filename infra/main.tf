provider "aws" {
  region = var.region
}

# ---------------------------
# Caller identity
# ---------------------------
data "aws_caller_identity" "current" {}

# ---------------------------
# Networking (VPC, Subnets, IGW, Routes)
# ---------------------------
resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "spring-boot-cicd-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-a" }
}

resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}c"
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-c" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------
# Security Groups
# ---------------------------

# ALB Security Group → allows 80 from world
resource "aws_security_group" "alb_sg" {
  name        = "spring-boot-alb-sg"
  description = "Allow inbound HTTP from internet"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ECS Task Security Group → allows 8080 only from ALB SG
resource "aws_security_group" "ecs_sg" {
  name        = "spring-boot-ecs-sg"
  description = "Allow traffic from ALB to ECS tasks"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------
# ECS Cluster
# ---------------------------
resource "aws_ecs_cluster" "this" {
  name = "spring-boot-cicd-cluster"
}

# ---------------------------
# IAM Role for ECS Task Execution (existing)
# ---------------------------
resource "aws_iam_role" "ecs_task_execution" {
  name               = "spring-boot-cicd-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_attach" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_secretsmanager_secret" "api_secret" {
  name        = "demo-api-secret"
  description = "Demo secret for spring-boot-cicd app (created by Terraform)"
  tags = {
    Name = "demo-api-secret"
  }
}

resource "aws_secretsmanager_secret_version" "api_secret_version" {
  secret_id     = aws_secretsmanager_secret.api_secret.id
  secret_string = jsonencode({
    apiKey = "CHANGE_ME",
    info   = "replace-this-value-with-your-real-secret"
  })
}

# ---------------------------
# ECS Task Role (for application runtime API calls)
# ---------------------------
data "aws_iam_policy_document" "task_policy" {
  statement {
    sid = "DynamoDBAccess"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:UpdateItem"
    ]
    resources = [
      "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table_name}"
    ]
  }

  statement {
    sid = "S3Access"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.s3_bucket_name}",
      "arn:aws:s3:::${var.s3_bucket_name}/*"
    ]
  }

  statement {
    sid = "SQSAccess"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:SendMessage"
    ]
    resources = [
      "arn:aws:sqs:${var.region}:${data.aws_caller_identity.current.account_id}:${var.sqs_name}",
      "arn:aws:sqs:${var.region}:${data.aws_caller_identity.current.account_id}:${var.sqs_name}-dlq"
    ]
  }

  statement {
    sid = "KMSAccess"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [
      aws_kms_key.app_key.arn
    ]
  }

  statement {
    sid = "SecretsManagerAccess"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      aws_secretsmanager_secret.api_secret.arn
    ]
  }

  statement {
    sid = "CloudWatchLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:CreateLogGroup",
      "logs:DescribeLogStreams"
    ]
    resources = [
      aws_cloudwatch_log_group.app.arn,
      "${aws_cloudwatch_log_group.app.arn}:*"
    ]
  }
}

resource "aws_iam_role" "ecs_task_role" {
  name               = "spring-boot-cicd-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
  tags = { Name = "spring-boot-cicd-task-role" }
}

resource "aws_iam_policy" "ecs_task_policy_obj" {
  name   = "spring-boot-cicd-task-policy"
  policy = data.aws_iam_policy_document.task_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_task_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_policy_obj.arn
}

# ---------------------------
# ECS Task Definition
# ---------------------------
resource "aws_ecs_task_definition" "app" {
  family                   = "spring-boot-cicd-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "spring-boot-cicd"
      image     = "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/spring-boot-cicd:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/spring-boot-cicd"
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }
      environment = [
        { name = "AWS_REGION",     value = var.region },
        { name = "DYNAMODB_TABLE", value = aws_dynamodb_table.demo.name },
        { name = "S3_BUCKET",      value = aws_s3_bucket.app_bucket.bucket },
        { name = "S3_KMS_KEY_ID",  value = aws_kms_key.app_key.key_id },
        { name = "SQS_QUEUE_URL",  value = aws_sqs_queue.main.id },
        { name = "SECRETS_ARN",    value = aws_secretsmanager_secret.api_secret.arn }
      ]
    }
  ])
}

# ---------------------------
# KMS key (for S3 SSE)
# ---------------------------
resource "aws_kms_key" "app_key" {
  description             = "KMS key for S3 SSE - test-key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "spring-boot-cicd-kms"
  }
}

resource "aws_kms_alias" "app_alias" {
  name          = var.kms_alias_name
  target_key_id = aws_kms_key.app_key.key_id
}

# ---------------------------
# S3 bucket with SSE-KMS default
# ---------------------------
resource "aws_s3_bucket" "app_bucket" {
  bucket        = var.s3_bucket_name
  force_destroy = true

  tags = {
    Name = "spring-boot-cicd-bucket"
  }
}

resource "aws_s3_bucket_ownership_controls" "app_bucket_owner" {
  bucket = aws_s3_bucket.app_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_sse" {
  bucket = aws_s3_bucket.app_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.app_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket = aws_s3_bucket.app_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------
# SQS: DLQ + main queue
# ---------------------------
resource "aws_sqs_queue" "dlq" {
  name                       = "${var.sqs_name}-dlq"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 1209600
  tags = { Name = "demo-dlq" }
}

resource "aws_sqs_queue" "main" {
  name                       = var.sqs_name
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 5
  })

  tags = { Name = "demo-queue" }
}

# ---------------------------
# DynamoDB table
# ---------------------------
resource "aws_dynamodb_table" "demo" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"

  attribute {
    name = "userId"
    type = "S"
  }

  tags = { Name = "demo-dynamodb-table" }
}

# ---------------------------
# Load Balancer
# ---------------------------
resource "aws_lb" "app" {
  name               = "spring-boot-cicd-alb"
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_c.id]
  security_groups    = [aws_security_group.alb_sg.id]
}

resource "aws_lb_target_group" "app" {
  name        = "spring-boot-cicd-tg-ip"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "ip"

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ---------------------------
# ECS Service
# ---------------------------
resource "aws_ecs_service" "app" {
  name            = "spring-boot-cicd-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.public_a.id, aws_subnet.public_c.id]
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "spring-boot-cicd"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.http]
}

# ---------------------------
# CloudWatch Logs (existing)
# ---------------------------
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/spring-boot-cicd"
  retention_in_days = 7
}
