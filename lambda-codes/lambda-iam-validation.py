import json
import boto3
import logging
from datetime import datetime

# Configuración básica de logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

iam_client = boto3.client('iam')
config_client = boto3.client('config')

def lambda_handler(event, context):
    logger.info("Evento recibido: %s", json.dumps(event))
    evaluations = []

    try:
        # Verificar el ResultToken
        result_token = event.get('resultToken', 'TESTMODE')
        is_test_mode = result_token == "TESTMODE"
        
        # Obtener usuarios IAM
        response = iam_client.list_users()
        users = response.get('Users', [])
        logger.info("Usuarios IAM encontrados: %s", [user['UserName'] for user in users])

        if not users:
            evaluations.append({
                "ComplianceResourceType": "AWS::::Account",
                "ComplianceResourceId": event.get('accountId', 'UnknownAccount'),
                "ComplianceType": "COMPLIANT",
                "OrderingTimestamp": datetime.utcnow().isoformat(),
                "Annotation": "No se encontraron usuarios IAM en la cuenta."
            })
        else:
            for user in users:
                evaluations.append({
                    "ComplianceResourceType": "AWS::IAM::User",
                    "ComplianceResourceId": user['UserName'],
                    "ComplianceType": "NON_COMPLIANT",
                    "OrderingTimestamp": datetime.utcnow().isoformat(),
                    "Annotation": f"Usuario IAM detectado: {user['UserName']}."
                })

        logger.info("Evaluaciones generadas: %s", json.dumps(evaluations))

        # Enviar evaluaciones a Config si no es test mode
        if not is_test_mode:
            response = config_client.put_evaluations(
                Evaluations=evaluations,
                ResultToken=result_token
            )
            logger.info("Respuesta de put_evaluations: %s", json.dumps(response))
        else:
            logger.info("Modo de prueba detectado, no se enviaron evaluaciones a Config.")

    except Exception as e:
        logger.error("Error al procesar el evento: %s", str(e))
        return {
            'statusCode': 500,
            'body': json.dumps("Error al procesar: " + str(e))
        }

    return {
        'Evaluations': evaluations
    }