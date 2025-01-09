resource "aws_iam_role" "s3_tag_checker_role" {
  name = "s3_tag_checker_role"

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

resource "aws_iam_role_policy" "s3_tag_checker_policy" {
  name = "s3_tag_checker_policy"
  role = aws_iam_role.s3_tag_checker_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketTagging",
          "config:PutEvaluations",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "s3_tag_checker" {
  filename      = "s3_tag_checker_lambda.zip"
  function_name = "s3_tag_checker"
  role          = aws_iam_role.s3_tag_checker_role.arn
  handler       = "s3_tag_checker_lambda.lambda_handler"
  runtime       = "python3.9"

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }
}

resource "aws_config_config_rule" "s3_tag_checker_rule" {
  name = "s3-tag-checker"

  source {
    owner             = "CUSTOM_LAMBDA"
    source_identifier = aws_lambda_function.s3_tag_checker.arn
    source_detail {
      message_type = "ConfigurationItemChangeNotification"
    }
  }

  scope {
    compliance_resource_types = ["AWS::S3::Bucket"]
  }
}

resource "aws_lambda_permission" "allow_config" {
  statement_id  = "AllowConfigInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_tag_checker.function_name
  principal     = "config.amazonaws.com"
}