import json
import boto3

def evaluate_compliance(configuration_item, rule_parameters):
    """Evaluate if the S3 bucket has required tags."""
    if configuration_item["resourceType"] != "AWS::S3::Bucket":
        return {
            "compliance_type": "NOT_APPLICABLE",
            "annotation": f"Resource type {configuration_item['resourceType']} is not applicable."
        }
    
    bucket_name = configuration_item["configuration"]["bucketName"]
    
    # Get the bucket's tags
    s3_client = boto3.client('s3')
    try:
        response = s3_client.get_bucket_tagging(Bucket=bucket_name)
        tags = {tag['Key']: tag['Value'] for tag in response.get('TagSet', [])}
    except s3_client.exceptions.ClientError as e:
        if e.response['Error']['Code'] == 'NoSuchTagSet':
            tags = {}
        else:
            raise e

    # Check if required tags are present (modify these as needed)
    required_tags = ["Environment", "Project", "Owner"]
    missing_tags = [tag for tag in required_tags if tag not in tags]

    if missing_tags:
        return {
            "compliance_type": "NON_COMPLIANT",
            "annotation": f"Missing required tags: {', '.join(missing_tags)}"
        }
    
    return {
        "compliance_type": "COMPLIANT",
        "annotation": "All required tags are present"
    }

def lambda_handler(event, context):
    """Handle AWS Config rule evaluation."""
    invoking_event = json.loads(event["invokingEvent"])
    configuration_item = invoking_event["configurationItem"]
    
    evaluation = evaluate_compliance(configuration_item, event.get("ruleParameters", {}))
    
    config = boto3.client('config')
    config.put_evaluations(
        Evaluations=[
            {
                'ComplianceResourceType': configuration_item['resourceType'],
                'ComplianceResourceId': configuration_item['resourceId'],
                'ComplianceType': evaluation['compliance_type'],
                'Annotation': evaluation['annotation'],
                'OrderingTimestamp': configuration_item['configurationItemCaptureTime']
            }
        ],
        ResultToken=event['resultToken']
    )

    return evaluation