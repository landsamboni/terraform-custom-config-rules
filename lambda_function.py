import json
import logging

# Configuración básica de logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info("Evento recibido: %s", json.dumps(event))

    evaluations = []

    # Parsear el evento para obtener un diccionario
    try:
        invoking_event = json.loads(event['invokingEvent'])
        logger.info("Evento parseado: %s", json.dumps(invoking_event))

        if 'configurationItem' in invoking_event:
            resource = invoking_event['configurationItem']
            logger.info("Recurso evaluado: %s", json.dumps(resource))

            # Validar si los tags requeridos existen
            required_tags = ["Environment", "Owner"]
            tags = resource.get('tags', {})
            missing_tags = [tag for tag in required_tags if tag not in tags]

            # Determinar el tipo de cumplimiento
            if missing_tags:
                compliance_type = "NON_COMPLIANT"
                annotation = f"Faltan los siguientes tags: {', '.join(missing_tags)}"
            else:
                compliance_type = "COMPLIANT"
                annotation = "Todos los tags requeridos están presentes."

            # Agregar evaluación
            evaluations.append({
                "ComplianceResourceType": resource['resourceType'],
                "ComplianceResourceId": resource['resourceId'],
                "ComplianceType": compliance_type,
                "OrderingTimestamp": resource['configurationItemCaptureTime'],
                "Annotation": annotation  # Explicación adicional del resultado
            })

    except Exception as e:
        logger.error("Error al procesar el evento: %s", str(e))

    logger.info("Evaluaciones generadas: %s", json.dumps(evaluations))

    return {
        'Evaluations': evaluations
    }