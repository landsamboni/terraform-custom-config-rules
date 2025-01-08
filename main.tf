# Crear un rol de IAM para la función Lambda
resource "aws_iam_role" "lambda_role" {
  name = "config_custom_rule_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Adjuntar una política al rol de IAM
resource "aws_iam_role_policy" "lambda_policy" {
  name = "custom_lambda_policy" # Nombre personalizado de la política
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ec2:DescribeInstances"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "config:PutEvaluations",
          "config:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Adjuntar la política administrada AWSConfigRulesExecutionRole al rol
resource "aws_iam_role_policy_attachment" "config_rules_execution_role_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRulesExecutionRole"
}

resource "aws_iam_role_policy_attachment" "ec2_full_access_policy-a" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}



# Crear la función Lambda
resource "aws_lambda_function" "custom_rule_function" {
  function_name = "custom-config-rule"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  timeout       = 10
  memory_size   = 128

  filename         = "${path.module}/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda.zip")
}

# Agregar permisos a la función Lambda para que AWS Config pueda invocarla
resource "aws_lambda_permission" "allow_config_invoke" {
  statement_id  = "AllowInvokeByConfig"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.custom_rule_function.function_name
  principal     = "config.amazonaws.com"
}

# Crear la regla personalizada de AWS Config
resource "aws_config_config_rule" "custom_rule" {
  name        = "custom-config-rule"
  description = "Validar que las instancias EC2 tengan etiquetas específicas."

  source {
    owner             = "CUSTOM_LAMBDA"
    source_identifier = aws_lambda_function.custom_rule_function.arn

    source_detail {
      event_source = "aws.config"
      message_type = "ConfigurationItemChangeNotification"
    }
  }

  input_parameters = jsonencode({
    RequiredTags = ["Environment", "Owner"]
  })
}





# ---------------------------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------------------------






# Crear un segundo rol de IAM para la nueva función Lambda
resource "aws_iam_role" "lambda_role_no_public_ip" {
  name = "config_no_public_ip_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Adjuntar una política al segundo rol de IAM
resource "aws_iam_role_policy" "lambda_policy_no_public_ip" {
  name = "noPublicIP_lambda_policy" # Nombre personalizado de la política
  role = aws_iam_role.lambda_role_no_public_ip.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ec2:DescribeInstances"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "config:PutEvaluations"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Crear la segunda función Lambda
resource "aws_lambda_function" "no_public_ip_function" {
  function_name = "no-public-ip-config-rule"
  role          = aws_iam_role.lambda_role_no_public_ip.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  timeout       = 10
  memory_size   = 128

  filename         = "${path.module}/no_public_ip_lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/no_public_ip_lambda.zip")
}


# Adjuntar la política administrada AWSConfigRulesExecutionRole al rol
resource "aws_iam_role_policy_attachment" "config_rules_execution_role_policy-b" {
  role       = aws_iam_role.lambda_role_no_public_ip.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRulesExecutionRole"
}

resource "aws_iam_role_policy_attachment" "ec2_full_access_policy-b" {
  role       = aws_iam_role.lambda_role_no_public_ip.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# Agregar permisos a la segunda función Lambda para que AWS Config pueda invocarla
resource "aws_lambda_permission" "allow_config_invoke_no_public_ip" {
  statement_id  = "AllowInvokeByConfigNoPublicIP"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.no_public_ip_function.function_name
  principal     = "config.amazonaws.com"
}

# Crear la segunda regla personalizada de AWS Config
resource "aws_config_config_rule" "no_public_ip_rule" {
  name        = "no-public-ip-rule"
  description = "Validar que las instancias EC2 no tengan direcciones IP públicas."

  source {
    owner             = "CUSTOM_LAMBDA"
    source_identifier = aws_lambda_function.no_public_ip_function.arn

    source_detail {
      event_source = "aws.config"
      message_type = "ConfigurationItemChangeNotification"
    }
  }
}
