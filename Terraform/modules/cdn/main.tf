variable "project_name" {}
variable "output_bucket_domain" {}
variable "output_bucket_id" {}

resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "${var.project_name} OAI"
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled         = true
  is_ipv6_enabled = true
  price_class     = "PriceClass_100"

  origin {
    domain_name = var.output_bucket_domain
    origin_id   = "S3-${var.output_bucket_id}"
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${var.output_bucket_id}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "oai_arn" { value = aws_cloudfront_origin_access_identity.oai.iam_arn }
output "cloudfront_url" { value = "https://${aws_cloudfront_distribution.cdn.domain_name}" }
