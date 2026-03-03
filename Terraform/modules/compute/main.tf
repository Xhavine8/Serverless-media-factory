variable "project_name" {}
variable "aws_region" {}
variable "ingest_bucket_id" {}
variable "ingest_bucket_arn" {}
variable "output_bucket_id" {}
variable "output_bucket_arn" {}
variable "dynamodb_table_name" {}
variable "dynamodb_table_arn" {}
variable "subnet_ids" {}
variable "security_group_id" {}
variable "dlq_arn" {}
variable "cloudfront_url" {}

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "lambda" {
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:HeadObject", "s3:ListBucket"], Resource = ["${var.ingest_bucket_arn}/*", "${var.output_bucket_arn}/*", var.ingest_bucket_arn, var.output_bucket_arn] },
      { Effect = "Allow", Action = ["mediaconvert:*"], Resource = "*" },
      { Effect = "Allow", Action = ["dynamodb:*"], Resource = var.dynamodb_table_arn },
      { Effect = "Allow", Action = ["kms:Decrypt", "kms:DescribeKey"], Resource = "*" },
      { Effect = "Allow", Action = ["logs:*"], Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.project_name}-*" },
      { Effect = "Allow", Action = ["ec2:CreateNetworkInterface", "ec2:DescribeNetworkInterfaces", "ec2:DeleteNetworkInterface"], Resource = "*" },
      { Effect = "Allow", Action = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"], Resource = "*" },
      { Effect = "Allow", Action = "sqs:SendMessage", Resource = var.dlq_arn },
      { Effect = "Allow", Action = "iam:PassRole", Resource = aws_iam_role.mediaconvert.arn }
    ]
  })
}

resource "aws_iam_role" "mediaconvert" {
  name = "${var.project_name}-mediaconvert-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "mediaconvert.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "mediaconvert" {
  role = aws_iam_role.mediaconvert.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject"], Resource = ["${var.ingest_bucket_arn}/*", "${var.output_bucket_arn}/*"] }]
  })
}

resource "aws_lambda_function" "transcoder" {
  filename                       = "lambda_function.zip"
  function_name                  = "${var.project_name}-transcoder"
  role                           = aws_iam_role.lambda.arn
  handler                        = "lambda_function.lambda_handler"
  source_code_hash               = filebase64sha256("lambda_function.zip")
  runtime                        = "python3.11"
  timeout                        = 60
  memory_size                    = 256

  environment {
    variables = {
      OUTPUT_BUCKET     = var.output_bucket_id
      MEDIACONVERT_ROLE = aws_iam_role.mediaconvert.arn
      DYNAMODB_TABLE    = var.dynamodb_table_name
      REGION            = var.aws_region
    }
  }

  dead_letter_config { target_arn = var.dlq_arn }
  tracing_config { mode = "Active" }
}

resource "aws_lambda_function" "api" {
  filename                       = "api_lambda.zip"
  function_name                  = "${var.project_name}-api"
  role                           = aws_iam_role.lambda.arn
  handler                        = "api_lambda.lambda_handler"
  source_code_hash               = filebase64sha256("api_lambda.zip")
  runtime                        = "python3.11"
  timeout     = 30

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
      OUTPUT_BUCKET  = var.output_bucket_id
      CLOUDFRONT_URL = var.cloudfront_url
      INGEST_BUCKET  = var.ingest_bucket_id
      REGION         = var.aws_region
    }
  }

  tracing_config { mode = "Active" }
}

resource "aws_lambda_permission" "s3" {
  statement_id  = "AllowS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transcoder.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.ingest_bucket_arn
}

output "transcoder_lambda_arn" { value = aws_lambda_function.transcoder.arn }
output "transcoder_lambda_name" { value = aws_lambda_function.transcoder.function_name }
output "api_lambda_arn" { value = aws_lambda_function.api.arn }
output "api_lambda_name" { value = aws_lambda_function.api.function_name }
