# Crear un rol de IAM para la función Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.function_name}-role"

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

  # Incluir directamente la política compartida
  inline_policy {
    name = "shared-lambda-policy"
    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Effect : "Allow",
          Action : [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogStreams"
          ],
          Resource : "arn:aws:logs:*:*:log-group:/aws/lambda/*"
        },
        {
          Effect : "Allow",
          Action : "config:PutEvaluations",
          Resource : "*"
        },
        {
          Effect : "Allow",
          Action : [
            "iam:List*",
            "iam:Get*"
          ],
          Resource : "*"
        },
        {
          Effect : "Allow",
          Action : "sts:AssumeRole",
          Resource : "*"
        }
      ]
    })
  }
}

resource "aws_iam_role_policy_attachment" "readonly_access_policy" {
  role       = aws_iam_role.lambda_role.id
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}



# Crear la función Lambda
resource "aws_lambda_function" "lambda" {
  function_name    = var.function_name
  role             = aws_iam_role.lambda_role.arn
  handler          = var.handler
  runtime          = var.runtime
  timeout          = var.timeout
  memory_size      = var.memory_size
  filename         = var.source_zip
  source_code_hash = filebase64sha256(var.source_zip)
}

# Permitir que AWS Config invoque la Lambda, con statement_id dinámico
resource "aws_lambda_permission" "allow_config_invoke" {
  statement_id  = "${var.function_name}-AllowInvokeByConfig"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal     = "config.amazonaws.com"
}
