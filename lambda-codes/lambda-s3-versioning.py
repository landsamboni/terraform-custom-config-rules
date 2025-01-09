import json
import logging
import boto3

# Basic logging configuration
logger = logging.getLogger()
logger.setLevel(logging.INFO)

client = boto3.client('config')
s3_client = boto3.client('s3')

def lambda_handler(event, context):
    logger.info("Event received: %s", json.dumps(event))
    evaluations = []

    try:
        invoking_event = json.loads(event['invokingEvent'])
        configuration_item = invoking_event.get('configurationItem')

        if not configuration_item:
            logger.info("The event does not contain a configurationItem.")
            return build_response(evaluations, event)

        if configuration_item['resourceType'] != 'AWS::S3::Bucket':
            logger.info("Resource not applicable: %s", configuration_item['resourceType'])
            return build_response(evaluations, event)

        bucket_name = configuration_item['resourceId']

        try:
            response = s3_client.get_bucket_versioning(Bucket=bucket_name)
            versioning_status = response.get('Status', 'Disabled')

            if versioning_status == 'Enabled':
                compliance_type = "COMPLIANT"
                annotation = "Versioning is enabled."
            else:
                compliance_type = "NON_COMPLIANT"
                annotation = "Versioning is not enabled."

        except Exception as e:
            compliance_type = "NON_COMPLIANT"
            annotation = f"Error verifying versioning: {str(e)}"
            logger.error("Error fetching versioning status: %s", str(e))

        # Truncate annotation if it's too long
        if len(annotation) > 256:
            annotation = annotation[:253] + "..."

        evaluations.append({
            "ComplianceResourceType": configuration_item['resourceType'],
            "ComplianceResourceId": bucket_name,
            "ComplianceType": compliance_type,
            "OrderingTimestamp": configuration_item['configurationItemCaptureTime'],
            "Annotation": annotation
        })

    except Exception as e:
        logger.error("Error processing the event: %s", str(e))

    return build_response(evaluations, event)

def build_response(evaluations, event):
    result_token = event['resultToken']
    try:
        response = client.put_evaluations(
            Evaluations=evaluations,
            ResultToken=result_token
        )
        logger.info("put_evaluations response: %s", json.dumps(response))
    except Exception as e:
        logger.error("Error sending evaluations: %s", str(e))
    return {
        'Evaluations': evaluations
    }