import json
import logging
import boto3

# Configuración básica de logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

client = boto3.client('config')

def lambda_handler(event, context):
    logger.info("Evento recibido: %s", json.dumps(event))
    evaluations = []

    try:
        # Parsear el evento para obtener el elemento de configuración
        invoking_event = json.loads(event['invokingEvent'])
        logger.info("Evento invocado: %s", json.dumps(invoking_event))

        configuration_item = invoking_event.get('configurationItem')
        if not configuration_item:
            logger.info("El evento no contiene configurationItem.")
            return build_response(evaluations, event)

        # Verificar si el recurso es aplicable
        if configuration_item['resourceType'] != 'AWS::EC2::Instance':
            logger.info("Recurso no aplicable: %s", configuration_item['resourceType'])
            return build_response(evaluations, event)

        # Validar si los tags requeridos existen
        required_tags = ["Environment", "Owner","Name"]
        tags = configuration_item.get('tags', {})
        missing_tags = [tag for tag in required_tags if tag not in tags]

        if missing_tags:
            compliance_type = "NON_COMPLIANT"
            annotation = f"Faltan los siguientes tags: {', '.join(missing_tags)}"
        else:
            compliance_type = "COMPLIANT"
            annotation = "Todos los tags requeridos están presentes."

        # Crear evaluación
        evaluations.append({
            "ComplianceResourceType": configuration_item['resourceType'],
            "ComplianceResourceId": configuration_item['resourceId'],
            "ComplianceType": compliance_type,
            "OrderingTimestamp": configuration_item['configurationItemCaptureTime'],
            "Annotation": annotation
        })

        logger.info("Evaluaciones generadas: %s", json.dumps(evaluations))

    except Exception as e:
        logger.error("Error al procesar el evento: %s", str(e))

    # Enviar las evaluaciones a AWS Config
    return build_response(evaluations, event)


def build_response(evaluations, event):
    """
    Enviar evaluaciones a AWS Config utilizando put_evaluations.
    """
    result_token = event['resultToken']
    try:
        response = client.put_evaluations(
            Evaluations=evaluations,
            ResultToken=result_token
        )
        logger.info("Respuesta de put_evaluations: %s", json.dumps(response))
    except Exception as e:
        logger.error("Error al enviar evaluaciones: %s", str(e))
    return {
        'Evaluations': evaluations
    }