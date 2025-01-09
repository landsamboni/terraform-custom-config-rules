import json
import boto3
import logging
from datetime import datetime

# Basic logging configuration
logger = logging.getLogger()
logger.setLevel(logging.INFO)

iam_client = boto3.client('iam')
config_client = boto3.client('config')

def lambda_handler(event, context):
    logger.info("Event received: %s", json.dumps(event))
    evaluations = []

    try:
        # Verify the ResultToken
        result_token = event.get('resultToken', 'TESTMODE')
        is_test_mode = result_token == "TESTMODE"
        
        # Retrieve IAM users
        response = iam_client.list_users()
        users = response.get('Users', [])
        logger.info("IAM users found: %s", [user['UserName'] for user in users])

        if not users:
            evaluations.append({
                "ComplianceResourceType": "AWS::::Account",
                "ComplianceResourceId": event.get('accountId', 'UnknownAccount'),
                "ComplianceType": "COMPLIANT",
                "OrderingTimestamp": datetime.utcnow().isoformat(),
                "Annotation": "No IAM users were found in the account."
            })
        else:
            for user in users:
                evaluations.append({
                    "ComplianceResourceType": "AWS::IAM::User",
                    "ComplianceResourceId": user['UserName'],
                    "ComplianceType": "NON_COMPLIANT",
                    "OrderingTimestamp": datetime.utcnow().isoformat(),
                    "Annotation": f"IAM user detected: {user['UserName']}."
                })

        logger.info("Generated evaluations: %s", json.dumps(evaluations))

        # Send evaluations to Config if not in test mode
        if not is_test_mode:
            response = config_client.put_evaluations(
                Evaluations=evaluations,
                ResultToken=result_token
            )
            logger.info("put_evaluations response: %s", json.dumps(response))
        else:
            logger.info("Test mode detected, evaluations were not sent to Config.")

    except Exception as e:
        logger.error("Error processing the event: %s", str(e))
        return {
            'statusCode': 500,
            'body': json.dumps("Error processing: " + str(e))
        }

    return {
        'Evaluations': evaluations
    }