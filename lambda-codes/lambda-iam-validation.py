import json
import boto3
import logging
from datetime import datetime

# Configuración básica de logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

client = boto3.client('iam')

def lambda_handler(event, context):
    logger.info("Evento recibido: %s", json.dumps(event))
    evaluations = []

    try:
        # Obtener la hora de ordenamiento
        ordering_timestamp = event.get('notificationCreationTime', datetime.utcnow().isoformat())

        # Listar usuarios IAM en la cuenta
        response = client.list_users()
        users = response.get('Users', [])

        if users:
            compliance_type = "NON_COMPLIANT"
            annotation = f"Existen usuarios IAM en la cuenta. Total: {len(users)}."
        else:
            compliance_type = "COMPLIANT"
            annotation = "No hay usuarios IAM en la cuenta."

        evaluations.append({
            "ComplianceResourceType": "AWS::::Account",
            "ComplianceResourceId": event['accountId'],
            "ComplianceType": compliance_type,
            "OrderingTimestamp": ordering_timestamp,
            "Annotation": annotation
        })

    except Exception as e:
        logger.error("Error al procesar el evento: %s", str(e))
        evaluations.append({
            "ComplianceResourceType": "AWS::::Account",
            "ComplianceResourceId": event.get('accountId', 'unknown'),
            "ComplianceType": "NON_COMPLIANT",
            "OrderingTimestamp": ordering_timestamp,
            "Annotation": f"Error al verificar los usuarios IAM: {str(e)[:250]}."
        })

    return build_response(evaluations, event)


def build_response(evaluations, event):
    """
    Enviar evaluaciones a AWS Config utilizando put_evaluations.
    """
    config_client = boto3.client('config')
    result_token = event.get('resultToken', 'unknown')

    try:
        response = config_client.put_evaluations(
            Evaluations=evaluations,
            ResultToken=result_token
        )
        logger.info("Respuesta de put_evaluations: %s", json.dumps(response))
    except Exception as e:
        logger.error("Error al enviar evaluaciones: %s", str(e))
    return {
        'Evaluations': evaluations
    }