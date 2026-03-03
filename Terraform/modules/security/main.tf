variable "project_name" {}
variable "environment" {}
variable "aws_region" {}
variable "ingest_bucket_arn" {}
variable "output_bucket_arn" {}

resource "aws_wafv2_web_acl" "main" {
  name  = "${var.project_name}-waf"
  scope = "REGIONAL"
  
  default_action {
    allow {}
  }

  rule {
    name     = "RateLimit"
    priority = 1
    
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf"
    sampled_requests_enabled   = true
  }
}

resource "aws_s3_bucket" "cloudtrail" {
  bucket = "${var.project_name}-cloudtrail-${var.environment}"
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "AWSCloudTrailAclCheck", Effect = "Allow", Principal = { Service = "cloudtrail.amazonaws.com" }, Action = "s3:GetBucketAcl", Resource = aws_s3_bucket.cloudtrail.arn },
      { Sid = "AWSCloudTrailWrite", Effect = "Allow", Principal = { Service = "cloudtrail.amazonaws.com" }, Action = "s3:PutObject", Resource = "${aws_s3_bucket.cloudtrail.arn}/*", Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } } }
    ]
  })
}

resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  depends_on                    = [aws_s3_bucket_policy.cloudtrail]
}

resource "aws_guardduty_detector" "main" {
  enable = true
  datasources {
    s3_logs { enable = true }
  }
}

output "waf_acl_arn" { value = aws_wafv2_web_acl.main.arn }
