variable "project_name" {}

resource "aws_kms_key" "dynamodb" {
  description             = "DynamoDB encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_dynamodb_table" "jobs" {
  name         = "${var.project_name}-jobs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "jobId"

  attribute {
    name = "jobId"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }

  point_in_time_recovery {
    enabled = true
  }
}

output "table_name" { value = aws_dynamodb_table.jobs.name }
output "table_arn" { value = aws_dynamodb_table.jobs.arn }
