output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.app_bucket.bucket
}

output "s3_bucket_arn" {
  value = aws_s3_bucket.app_bucket.arn
}

output "kms_key_id" {
  value = aws_kms_key.app_key.key_id
}

output "kms_key_arn" {
  value = aws_kms_key.app_key.arn
}

output "kms_alias" {
  value = aws_kms_alias.app_alias.name
}

output "sqs_queue_url" {
  value = aws_sqs_queue.main.id
}

output "sqs_queue_arn" {
  value = aws_sqs_queue.main.arn
}

output "sqs_dlq_arn" {
  value = aws_sqs_queue.dlq.arn
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.demo.name
}

output "secrets_arn" {
  value = aws_secretsmanager_secret.api_secret.arn
}

output "ecs_task_role_arn" {
  value = aws_iam_role.ecs_task_role.arn
}

output "cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.app.name
}

