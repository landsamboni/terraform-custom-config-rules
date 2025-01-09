import json
import logging
import boto3

# Configuración básica de logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

client = boto3.client('config')
s3_client = boto3.client('s3')

def lambda_handler(event, context):
    logger.info("Evento recibido: %s", json.dumps(event))
    evaluations = []

    try:
        invoking_event = json.loads(event['invokingEvent'])
        configuration_item = invoking_event.get('configurationItem')

        if not configuration_item:
            logger.info("El evento no contiene configurationItem.")
            return build_response(evaluations, event)

        if configuration_item['resourceType'] != 'AWS::S3::Bucket':
            logger.info("Recurso no aplicable: %s", configuration_item['resourceType'])
            return build_response(evaluations, event)

        bucket_name = configuration_item['resourceId']

        try:
            response = s3_client.get_bucket_versioning(Bucket=bucket_name)
            versioning_status = response.get('Status', 'Disabled')

            if versioning_status == 'Enabled':
                compliance_type = "COMPLIANT"
                annotation = "El versioning está habilitado."
            else:
                compliance_type = "NON_COMPLIANT"
                annotation = "El versioning no está habilitado."

        except Exception as e:
            compliance_type = "NON_COMPLIANT"
            annotation = f"Error al verificar el versioning: {str(e)}"
            logger.error("Error al obtener el estado de versioning: %s", str(e))

        # Truncar anotación si es demasiado larga
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
        logger.error("Error al procesar el evento: %s", str(e))

    return build_response(evaluations, event)

def build_response(evaluations, event):
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