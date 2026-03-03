variable "project_name" {}
variable "aws_region" {}
variable "transcoder_lambda_name" {}

resource "aws_sns_topic" "alerts" {
  name              = "${var.project_name}-alerts"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      { type = "metric", properties = { metrics = [["AWS/Lambda", "Invocations", { stat = "Sum" }]], period = 300, region = var.aws_region, title = "Videos Processed" } },
      { type = "metric", properties = { metrics = [["AWS/Lambda", "Errors", { stat = "Sum" }]], period = 300, region = var.aws_region, title = "Errors" } }
    ]
  })
}

output "sns_topic_arn" { value = aws_sns_topic.alerts.arn }
