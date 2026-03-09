# Serverless Media Factory

A fully serverless video transcoding pipeline built on AWS that automatically converts uploaded videos into multiple formats (1080p and 720p) using AWS MediaConvert.

## Architecture

- **Frontend**: React application for video upload and status monitoring
- **API**: AWS API Gateway + Lambda for REST endpoints
- **Processing**: AWS Lambda + MediaConvert for video transcoding
- **Storage**: S3 for input/output, DynamoDB for job tracking
- **Delivery**: CloudFront CDN for fast video delivery
- **Infrastructure**: Terraform for IaC deployment

## Features

- ✅ Drag-and-drop video upload
- ✅ Automatic transcoding to 1080p and 720p
- ✅ Real-time status polling
- ✅ CloudFront CDN delivery
- ✅ Serverless architecture (pay per use)
- ✅ Encrypted storage (S3 + DynamoDB)
- ✅ VPC networking with endpoints
- ✅ CloudWatch monitoring and alarms
- ✅ WAF protection
- ✅ CloudTrail auditing

## Prerequisites

- AWS Account
- Terraform >= 1.0
- Node.js >= 14
- Python 3.11
- AWS CLI configured

## Deployment

### 1. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review plan
terraform plan

# Deploy
terraform apply
```

### 2. Deploy Lambda Functions

```bash
# Package Lambda functions
python -m zipfile -c lambda_function.zip lambda_function.py
python -m zipfile -c api_lambda.zip api_lambda.py

# Functions are automatically deployed via Terraform
```

### 3. Deploy Frontend

```bash
cd frontend

# Install dependencies
npm install

# Update API endpoint in src/App.js with your API Gateway URL
# Update CloudFront URL in src/App.js

# Start development server
npm start

# Or build for production
npm run build
```

## Configuration

Update `terraform.tfvars`:

```hcl
aws_region   = "us-east-1"
project_name = "media-factory"
environment  = "prod"
```

## Usage

1. Open the frontend application
2. Click to select or drag-and-drop an MP4 video file
3. Click "Start Processing"
4. Wait for transcoding to complete
5. Preview or download the 1080p and 720p versions

## Architecture Components

### Storage
- **Ingest Bucket**: Receives uploaded videos
- **Output Bucket**: Stores transcoded videos
- **DynamoDB**: Tracks job status and metadata

### Compute
- **Transcoder Lambda**: Triggered by S3, submits MediaConvert jobs
- **API Lambda**: Handles upload URLs and status queries
- **MediaConvert**: Performs video transcoding

### Networking
- **VPC**: Private network for Lambda functions
- **VPC Endpoints**: S3 and DynamoDB access without internet
- **CloudFront**: CDN for video delivery

### Security
- **IAM Roles**: Least privilege access
- **KMS**: Encryption for DynamoDB
- **WAF**: API protection
- **GuardDuty**: Threat detection
- **CloudTrail**: Audit logging

## API Endpoints

- `GET /upload-url?filename={name}` - Get presigned upload URL
- `GET /status/{jobId}` - Get job status
- `GET /job-id?filename={name}` - Get job ID from filename

## Cost Optimization

- **S3 Lifecycle**: Moves ingest files to Glacier after 1 day
- **DynamoDB**: On-demand pricing
- **Lambda**: Pay per invocation
- **MediaConvert**: Pay per minute of video processed
- **CloudFront**: Pay per GB delivered

## Monitoring

- CloudWatch Dashboard: `media-factory-dashboard`
- Lambda Error Alarm: Triggers SNS notification
- X-Ray Tracing: Enabled on all Lambda functions

## Cleanup

```bash
# Destroy all resources
terraform destroy

# Manually empty S3 buckets first if needed
aws s3 rm s3://media-factory-ingest-prod --recursive
aws s3 rm s3://media-factory-output-prod --recursive
```

## Troubleshooting

### Videos not processing
- Check Lambda logs: `/aws/lambda/media-factory-transcoder`
- Verify S3 trigger is configured
- Check IAM permissions

### Status stuck at PROCESSING
- Check API Lambda logs: `/aws/lambda/media-factory-api`
- Verify KMS and S3 permissions
- Check MediaConvert job status in console

### CloudFront 403 errors
- Verify OAI permissions on output bucket
- Check bucket policy allows CloudFront access

## License

MIT

## Author

[Andrew Leshan]
leshanandrew76@gmail.com
