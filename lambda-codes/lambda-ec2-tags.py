import json
import logging
import boto3


logger = logging.getLogger()
logger.setLevel(logging.INFO)

config_client = boto3.client('config')

def lambda_handler(event, context):
    logger.info("Event received: %s", json.dumps(event))
    evaluations = []

    try:        
        invoking_event = json.loads(event.get('invokingEvent', '{}'))
        configuration_item = invoking_event.get('configurationItem')

        if not configuration_item:
            logger.warning("The event does not contain a configurationItem.")
            return build_response(evaluations, event)

        
        if configuration_item.get('resourceType') != 'AWS::EC2::Instance':
            logger.info("Non-applicable resource type: %s", configuration_item.get('resourceType'))
            return build_response(evaluations, event)

        
        required_tags = ["Environment", "Owner", "Name"]
        tags = configuration_item.get('tags', {})
        
        if not isinstance(tags, dict):
            logger.warning("Tags are not in the expected format: %s", tags)
            tags = {}

        missing_tags = [tag for tag in required_tags if tag not in tags]

        
        if missing_tags:
            compliance_type = "NON_COMPLIANT"
            annotation = f"Missing tags: {', '.join(missing_tags)}."
        else:
            compliance_type = "COMPLIANT"
            annotation = "All required tags are present."

        
        evaluations.append({
            "ComplianceResourceType": configuration_item['resourceType'],
            "ComplianceResourceId": configuration_item['resourceId'],
            "ComplianceType": compliance_type,
            "OrderingTimestamp": configuration_item['configurationItemCaptureTime'],
            "Annotation": annotation[:256]  
        })

        logger.info("Generated evaluations: %s", json.dumps(evaluations))

    except KeyError as ke:
        logger.error("KeyError encountered: %s", str(ke))
    except Exception as e:
        logger.error("Error processing the event: %s", str(e))

    
    return build_response(evaluations, event)

def build_response(evaluations, event):
    """
    Envía las evaluaciones a AWS Config usando put_evaluations.
    """
    result_token = event.get('resultToken', 'TESTMODE')

    try:
        response = config_client.put_evaluations(
            Evaluations=evaluations,
            ResultToken=result_token
        )
        logger.info("put_evaluations response: %s", json.dumps(response))
    except Exception as e:
        logger.error("Error sending evaluations: %s", str(e))
    
    return {
        'Evaluations': evaluations
    }