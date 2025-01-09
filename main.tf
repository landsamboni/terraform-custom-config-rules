
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

# Crear una política personalizada para la Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "custom_lambda_policy_model"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid : "WriteCloudWatchLogs",
        Action : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/RDK-Rule-Function*",
        Effect   = "Allow"
      },
      {
        Sid : "PutConfigEvaluations",
        Action : [
          "config:PutEvaluations"
        ],
        Resource = "*",
        Effect   = "Allow"
      },
      {
        Sid : "ReadIamResources",
        Action : [
          "iam:List*",
          "iam:Get*"
        ],
        Resource = "*",
        Effect   = "Allow"
      },
      {
        Sid : "AllowRoleAssumption",
        Action : [
          "sts:AssumeRole"
        ],
        Resource = "*",
        Effect   = "Allow"
      }
    ]
  })
}

# Adjuntar políticas administradas al rol de IAM
resource "aws_iam_role_policy_attachment" "config_rules_execution_role_policy" {
  role       = aws_iam_role.lambda_role.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRulesExecutionRole"
}

resource "aws_iam_role_policy_attachment" "readonly_access_policy" {
  role       = aws_iam_role.lambda_role.id
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Crear la función Lambda
resource "aws_lambda_function" "custom_rule_function" {
  function_name = "superman-config-rule"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  timeout       = 10
  memory_size   = 128

  filename         = "${path.module}/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda.zip")
}

# Permitir que AWS Config invoque la Lambda
resource "aws_lambda_permission" "allow_config_invoke" {
  statement_id  = "AllowInvokeByConfig"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.custom_rule_function.arn
  principal     = "config.amazonaws.com"
}

# Crear la regla personalizada de AWS Config
resource "aws_config_config_rule" "custom_rule" {
  name        = "superman-config-rule"
  description = "Validar que las instancias EC2 tengan etiquetas específicas."

  source {
    owner             = "CUSTOM_LAMBDA"
    source_identifier = aws_lambda_function.custom_rule_function.arn

    source_detail {
      event_source = "aws.config"
      message_type = "ConfigurationItemChangeNotification"
    }
  }

  scope {
    compliance_resource_types = ["AWS::EC2::Instance"]
  }

  input_parameters = jsonencode({
    RequiredTags = ["Environment", "Owner"]
  })

  depends_on = [
    aws_lambda_permission.allow_config_invoke,
    aws_lambda_function.custom_rule_function
  ]
}
