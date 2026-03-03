variable "project_name" {}
variable "environment" {}
variable "cloudfront_oai_arn" {}
variable "transcoder_lambda_arn" {}

resource "aws_s3_bucket" "ingest" {
  bucket = "${var.project_name}-ingest-${var.environment}"
}

resource "aws_s3_bucket_cors_configuration" "ingest" {
  bucket = aws_s3_bucket.ingest.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ingest" {
  bucket = aws_s3_bucket.ingest.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_versioning" "ingest" {
  bucket = aws_s3_bucket.ingest.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "ingest" {
  bucket                  = aws_s3_bucket.ingest.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "ingest" {
  bucket = aws_s3_bucket.ingest.id
  rule {
    id     = "glacier"
    status = "Enabled"
    filter {}
    transition {
      days          = 1
      storage_class = "GLACIER"
    }
  }
}

resource "aws_s3_bucket_notification" "ingest" {
  bucket = aws_s3_bucket.ingest.id
  lambda_function {
    lambda_function_arn = var.transcoder_lambda_arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".mp4"
  }
}

resource "aws_s3_bucket" "output" {
  bucket = "${var.project_name}-output-${var.environment}"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "output" {
  bucket = aws_s3_bucket.output.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "output" {
  bucket                  = aws_s3_bucket.output.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "output" {
  bucket = aws_s3_bucket.output.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "CloudFrontAccess"
      Effect    = "Allow"
      Principal = { AWS = var.cloudfront_oai_arn }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.output.arn}/*"
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.output]
}

output "ingest_bucket_id" { value = aws_s3_bucket.ingest.id }
output "ingest_bucket_arn" { value = aws_s3_bucket.ingest.arn }
output "output_bucket_id" { value = aws_s3_bucket.output.id }
output "output_bucket_arn" { value = aws_s3_bucket.output.arn }
output "output_bucket_domain" { value = aws_s3_bucket.output.bucket_regional_domain_name }
