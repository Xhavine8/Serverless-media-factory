terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.aws_region
}

module "networking" {
  source       = "./Terraform/modules/networking"
  project_name = var.project_name
  aws_region   = var.aws_region
}

module "cdn" {
  source               = "./Terraform/modules/cdn"
  project_name         = var.project_name
  output_bucket_domain = module.storage.output_bucket_domain
  output_bucket_id     = module.storage.output_bucket_id
}

module "database" {
  source       = "./Terraform/modules/database"
  project_name = var.project_name
}

module "messaging" {
  source       = "./Terraform/modules/messaging"
  project_name = var.project_name
}

module "compute" {
  source              = "./Terraform/modules/compute"
  project_name        = var.project_name
  aws_region          = var.aws_region
  ingest_bucket_id    = module.storage.ingest_bucket_id
  ingest_bucket_arn   = module.storage.ingest_bucket_arn
  output_bucket_id    = module.storage.output_bucket_id
  output_bucket_arn   = module.storage.output_bucket_arn
  dynamodb_table_name = module.database.table_name
  dynamodb_table_arn  = module.database.table_arn
  subnet_ids          = module.networking.private_subnet_ids
  security_group_id   = module.networking.lambda_sg_id
  dlq_arn             = module.messaging.dlq_arn
  cloudfront_url      = module.cdn.cloudfront_url
}

module "storage" {
  source                = "./Terraform/modules/storage"
  project_name          = var.project_name
  environment           = var.environment
  cloudfront_oai_arn    = module.cdn.oai_arn
  transcoder_lambda_arn = module.compute.transcoder_lambda_arn
}

module "security" {
  source            = "./Terraform/modules/security"
  project_name      = var.project_name
  environment       = var.environment
  aws_region        = var.aws_region
  ingest_bucket_arn = module.storage.ingest_bucket_arn
  output_bucket_arn = module.storage.output_bucket_arn
}

module "api" {
  source          = "./Terraform/modules/api"
  project_name    = var.project_name
  api_lambda_arn  = module.compute.api_lambda_arn
  api_lambda_name = module.compute.api_lambda_name
  waf_acl_arn     = module.security.waf_acl_arn
}

module "monitoring" {
  source                 = "./Terraform/modules/monitoring"
  project_name           = var.project_name
  aws_region             = var.aws_region
  transcoder_lambda_name = module.compute.transcoder_lambda_name
}

output "ingest_bucket" { value = module.storage.ingest_bucket_id }
output "output_bucket" { value = module.storage.output_bucket_id }
output "cloudfront_url" { value = module.cdn.cloudfront_url }
output "api_endpoint" { value = module.api.api_endpoint }
output "dynamodb_table" { value = module.database.table_name }
