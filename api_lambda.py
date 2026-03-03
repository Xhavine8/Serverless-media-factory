import json
import os
import boto3

REGION = os.environ.get('REGION', 'us-east-1')

dynamodb = boto3.resource('dynamodb', region_name=REGION)
s3 = boto3.client('s3', region_name=REGION)

DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
OUTPUT_BUCKET = os.environ['OUTPUT_BUCKET']
CLOUDFRONT_URL = os.environ['CLOUDFRONT_URL']
INGEST_BUCKET = os.environ.get('INGEST_BUCKET', OUTPUT_BUCKET)

def lambda_handler(event, context):
    print(f"Event: {json.dumps(event)}")
    
    route_key = event.get('routeKey') or f"{event.get('httpMethod', 'GET')} {event.get('resource', event.get('rawPath', ''))}"
    
    if 'status' in route_key or '/status/' in route_key:
        return get_status(event)
    elif 'upload-url' in route_key:
        return get_upload_url(event)
    elif 'job-id' in route_key:
        return get_job_id(event)
    
    return {'statusCode': 404, 'body': json.dumps({'error': 'Not found'})}

def get_status(event):
    path_params = event.get('pathParameters', {})
    job_id = path_params.get('jobId') or event.get('rawPath', '').split('/')[-1]
    table = dynamodb.Table(DYNAMODB_TABLE)
    response = table.get_item(Key={'jobId': job_id})
    
    if 'Item' not in response:
        return {'statusCode': 404, 'body': json.dumps({'error': 'Job not found'})}
    
    item = response['Item']
    
    if item['status'] == 'PROCESSING' and 'mediaConvertJobId' in item:
        try:
            endpoints = boto3.client('mediaconvert', region_name=REGION).describe_endpoints()
            mediaconvert = boto3.client('mediaconvert', region_name=REGION, endpoint_url=endpoints['Endpoints'][0]['Url'])
            mc_response = mediaconvert.get_job(Id=item['mediaConvertJobId'])
            mc_status = mc_response['Job']['Status']
            
            if mc_status == 'COMPLETE':
                item['status'] = 'COMPLETE'
                # Get actual output filenames from S3
                s3_response = boto3.client('s3', region_name=REGION).list_objects_v2(
                    Bucket=OUTPUT_BUCKET,
                    Prefix=f"{job_id}/"
                )
                outputs = {}
                if 'Contents' in s3_response:
                    for obj in s3_response['Contents']:
                        key = obj['Key']
                        if '1080p' in key:
                            outputs['1080p'] = f"{CLOUDFRONT_URL}/{key}"
                        elif '720p' in key:
                            outputs['720p'] = f"{CLOUDFRONT_URL}/{key}"
                item['outputs'] = outputs
                table.update_item(
                    Key={'jobId': job_id},
                    UpdateExpression='SET #status = :status, outputs = :outputs',
                    ExpressionAttributeNames={'#status': 'status'},
                    ExpressionAttributeValues={':status': 'COMPLETE', ':outputs': item['outputs']}
                )
            elif mc_status == 'ERROR':
                item['status'] = 'ERROR'
                table.update_item(
                    Key={'jobId': job_id},
                    UpdateExpression='SET #status = :status',
                    ExpressionAttributeNames={'#status': 'status'},
                    ExpressionAttributeValues={':status': 'ERROR'}
                )
        except Exception as e:
            print(f"Error checking MediaConvert status: {str(e)}")
    
    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
        'body': json.dumps(item, default=str)
    }

def get_job_id(event):
    params = event.get('queryStringParameters', {})
    filename = params.get('filename')
    
    if not filename:
        return {'statusCode': 400, 'body': json.dumps({'error': 'filename required'})}
    
    try:
        metadata = s3.head_object(Bucket=INGEST_BUCKET, Key=filename)
        job_id = metadata.get('Metadata', {}).get('jobid')
        
        if not job_id:
            return {'statusCode': 404, 'body': json.dumps({'error': 'Job ID not found'})}
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'jobId': job_id})
        }
    except Exception as e:
        print(f"Error getting job ID: {str(e)}")
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}

def get_upload_url(event):
    params = event.get('queryStringParameters', {})
    filename = params.get('filename', 'upload.mp4')
    
    job_id = str(__import__('uuid').uuid4())
    
    presigned_url = s3.generate_presigned_url(
        'put_object',
        Params={
            'Bucket': INGEST_BUCKET, 
            'Key': filename, 
            'ContentType': 'video/mp4',
            'Metadata': {'jobid': job_id}
        },
        ExpiresIn=3600
    )
    
    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
        'body': json.dumps({'uploadUrl': presigned_url, 'filename': filename, 'jobId': job_id})
    }
