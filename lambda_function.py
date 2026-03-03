import json
import os
import boto3
import uuid
from datetime import datetime, timedelta
from urllib.parse import unquote_plus

mediaconvert = boto3.client('mediaconvert')
dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')

OUTPUT_BUCKET = os.environ['OUTPUT_BUCKET']
MEDIACONVERT_ROLE = os.environ['MEDIACONVERT_ROLE']
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
AWS_REGION = os.environ.get('AWS_REGION', os.environ.get('REGION', 'us-east-1'))

def get_mediaconvert_endpoint():
    endpoints = mediaconvert.describe_endpoints()
    return endpoints['Endpoints'][0]['Url']

def lambda_handler(event, context):
    try:
        record = event['Records'][0]
        bucket = record['s3']['bucket']['name']
        key = unquote_plus(record['s3']['object']['key'])
        
        # Get jobId from object metadata
        obj_metadata = s3.head_object(Bucket=bucket, Key=key)
        job_id = obj_metadata.get('Metadata', {}).get('jobid')
        
        if not job_id:
            job_id = str(uuid.uuid4())
        
        input_path = f"s3://{bucket}/{key}"
        output_path = f"s3://{OUTPUT_BUCKET}/{job_id}/"
        
        mc_client = boto3.client('mediaconvert', endpoint_url=get_mediaconvert_endpoint())
        
        job_settings = {
            "OutputGroups": [{
                "Name": "File Group",
                "OutputGroupSettings": {
                    "Type": "FILE_GROUP_SETTINGS",
                    "FileGroupSettings": {
                        "Destination": output_path,
                        "DestinationSettings": {
                            "S3Settings": {
                                "StorageClass": "STANDARD"
                            }
                        }
                    }
                },
                "Outputs": [
                    {
                        "NameModifier": "1080p",
                        "VideoDescription": {
                            "Width": 1920,
                            "Height": 1080,
                            "CodecSettings": {
                                "Codec": "H_264",
                                "H264Settings": {"RateControlMode": "QVBR", "MaxBitrate": 5000000}
                            }
                        },
                        "AudioDescriptions": [{
                            "CodecSettings": {
                                "Codec": "AAC",
                                "AacSettings": {"Bitrate": 128000, "SampleRate": 48000, "CodingMode": "CODING_MODE_2_0"}
                            }
                        }],
                        "ContainerSettings": {"Container": "MP4"}
                    },
                    {
                        "NameModifier": "720p",
                        "VideoDescription": {
                            "Width": 1280,
                            "Height": 720,
                            "CodecSettings": {
                                "Codec": "H_264",
                                "H264Settings": {"RateControlMode": "QVBR", "MaxBitrate": 3000000}
                            }
                        },
                        "AudioDescriptions": [{
                            "CodecSettings": {
                                "Codec": "AAC",
                                "AacSettings": {"Bitrate": 128000, "SampleRate": 48000, "CodingMode": "CODING_MODE_2_0"}
                            }
                        }],
                        "ContainerSettings": {"Container": "MP4"}
                    }
                ]
            }],
            "Inputs": [{
                "FileInput": input_path,
                "AudioSelectors": {"Audio Selector 1": {"DefaultSelection": "DEFAULT"}}
            }]
        }
        
        response = mc_client.create_job(Role=MEDIACONVERT_ROLE, Settings=job_settings)
        mc_job_id = response['Job']['Id']
        
        table = dynamodb.Table(DYNAMODB_TABLE)
        table.put_item(Item={
            'jobId': job_id,
            'mediaConvertJobId': mc_job_id,
            'status': 'PROCESSING',
            'inputFile': key,
            'outputPath': output_path,
            'createdAt': datetime.utcnow().isoformat(),
            'ttl': int((datetime.utcnow() + timedelta(days=7)).timestamp())
        })
        
        return {'statusCode': 200, 'body': json.dumps({'jobId': job_id, 'status': 'PROCESSING'})}
    except Exception as e:
        print(f"Error: {str(e)}")
        raise
