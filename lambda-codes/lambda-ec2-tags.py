import json
import logging
import boto3

# Basic logging configuration
logger = logging.getLogger()
logger.setLevel(logging.INFO)

client = boto3.client('config')

def lambda_handler(event, context):
    logger.info("Event received: %s", json.dumps(event))
    evaluations = []

    try:
        # Parse the event to obtain the configuration item
        invoking_event = json.loads(event['invokingEvent'])
        logger.info("Invoking event: %s", json.dumps(invoking_event))

        configuration_item = invoking_event.get('configurationItem')
        if not configuration_item:
            logger.info("The event does not contain a configurationItem.")
            return build_response(evaluations, event)

        # Check if the resource is applicable
        if configuration_item['resourceType'] != 'AWS::EC2::Instance':
            logger.info("Non-applicable resource: %s", configuration_item['resourceType'])
            return build_response(evaluations, event)

        # Validate if the required tags exist
        required_tags = ["Environment", "Owner", "Name"]
        tags = configuration_item.get('tags', {})
        missing_tags = [tag for tag in required_tags if tag not in tags]

        if missing_tags:
            compliance_type = "NON_COMPLIANT"
            annotation = f"The following tags are missing: {', '.join(missing_tags)}"
        else:
            compliance_type = "COMPLIANT"
            annotation = "All required tags are present."

        # Create evaluation
        evaluations.append({
            "ComplianceResourceType": configuration_item['resourceType'],
            "ComplianceResourceId": configuration_item['resourceId'],
            "ComplianceType": compliance_type,
            "OrderingTimestamp": configuration_item['configurationItemCaptureTime'],
            "Annotation": annotation
        })

        logger.info("Generated evaluations: %s", json.dumps(evaluations))

    except Exception as e:
        logger.error("Error processing the event: %s", str(e))

    # Send evaluations to AWS Config
    return build_response(evaluations, event)


def build_response(evaluations, event):
    """
    Send evaluations to AWS Config using put_evaluations.
    """
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