import json
import logging
import boto3
from datetime import datetime

# Basic logging configuration
logger = logging.getLogger()
logger.setLevel(logging.INFO)

config_client = boto3.client('config')
securityhub_client = boto3.client('securityhub')

def lambda_handler(event, context):
    logger.info("Event received: %s", json.dumps(event))
    evaluations = []
    findings = []  # Findings to send to Security Hub

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
            severity = 5.0  # Set an appropriate severity level
        else:
            compliance_type = "COMPLIANT"
            annotation = "All required tags are present."
            severity = 0.0

        # Create evaluation
        evaluations.append({
            "ComplianceResourceType": configuration_item['resourceType'],
            "ComplianceResourceId": configuration_item['resourceId'],
            "ComplianceType": compliance_type,
            "OrderingTimestamp": configuration_item['configurationItemCaptureTime'],
            "Annotation": annotation
        })

        logger.info("Generated evaluations: %s", json.dumps(evaluations))

        # Create finding for Security Hub if NON_COMPLIANT
        if compliance_type == "NON_COMPLIANT":
            findings.append({
                "SchemaVersion": "2018-10-08",
                "Id": f"{configuration_item['resourceId']}/tag-check",
                "ProductArn": f"arn:aws:securityhub:{context.invoked_function_arn.split(':')[3]}:{context.invoked_function_arn.split(':')[4]}:product/{context.invoked_function_arn.split(':')[4]}/default",
                "GeneratorId": "custom-ec2-tag-check",
                "AwsAccountId": context.invoked_function_arn.split(':')[4],
                "Types": ["Software and Configuration Checks/Compliance"],
                "FirstObservedAt": datetime.utcnow().isoformat() + "Z",
                "CreatedAt": datetime.utcnow().isoformat() + "Z",
                "UpdatedAt": datetime.utcnow().isoformat() + "Z",
                "Severity": {"Normalized": int(severity * 20), "Product": severity},
                "Title": "EC2 Tag - Popular Config Custom Rule",
                "Description": annotation,
                "Resources": [
                    {
                        "Type": "AwsEc2Instance",
                        "Id": configuration_item['resourceId'],
                        "Region": configuration_item.get('awsRegion', context.invoked_function_arn.split(':')[3]),
                    }
                ],
                "Compliance": {"Status": "FAILED" if severity > 0 else "PASSED"},
                "Workflow": {"Status": "NEW"},
                "RecordState": "ACTIVE",
            })

        # Send findings to Security Hub
        if findings:
            response = securityhub_client.batch_import_findings(Findings=findings)
            logger.info("Security Hub response: %s", json.dumps(response))

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