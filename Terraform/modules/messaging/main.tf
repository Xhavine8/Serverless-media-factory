variable "project_name" {}

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_name}-dlq"
  message_retention_seconds = 1209600
  kms_master_key_id         = "alias/aws/sqs"
}

output "dlq_arn" { value = aws_sqs_queue.dlq.arn }
