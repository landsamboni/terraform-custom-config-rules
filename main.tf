/* ------------------------------------------------------------ */
/*                            RULE 1 - EC2 TAGS
/* ------------------------------------------------------------ */

data "archive_file" "lambda_ec2_tags_package" {
  type        = "zip"
  source_file = "./lambda-codes/lambda-ec2-tags.py"
  output_path = "${path.root}/lambda-codes/lambda-ec2-tags.zip"
}

module "lambda-ec2-tags" {
  source        = "./modules/mod-lambda"
  function_name = "lambda-ec2-tags"
  handler       = "lambda-ec2-tags.lambda_handler"
  runtime       = "python3.9"
  memory_size   = 128
  timeout       = 10
  source_zip    = "${path.root}/lambda-codes/lambda-ec2-tags.zip"
}

resource "aws_config_config_rule" "custom_rule" {
  name        = "ec2-tags"
  description = "Checks for specific EC2 Instance tags"

  source {
    owner             = "CUSTOM_LAMBDA"
    source_identifier = module.lambda-ec2-tags.lambda_arn


    source_detail {
      event_source = "aws.config"
      message_type = "ConfigurationItemChangeNotification"
    }
  }

  scope {
    compliance_resource_types = ["AWS::EC2::Instance"]
  }

  input_parameters = jsonencode({
    RequiredTags = ["Environment", "Owner", "Name"]

  })

}




/* ------------------------------------------------------------ */
/*                    RULE 2 - S3 VERSIONING VALIDATION
/* ------------------------------------------------------------ */


data "archive_file" "lambda_s3_versioning_package" {
  type        = "zip"
  source_file = "./lambda-codes/lambda-s3-versioning.py"
  output_path = "${path.root}/lambda-codes/lambda-s3-versioning.zip"
}

module "lambda_module_2" {
  source        = "./modules/mod-lambda"
  function_name = "lambda-s3-versioning-enabled"
  handler       = "lambda-s3-versioning.lambda_handler"
  runtime       = "python3.9"
  memory_size   = 128
  timeout       = 10
  source_zip    = "${path.root}/lambda-codes/lambda-s3-versioning.zip"
}


resource "aws_config_config_rule" "custom_rule_2" {
  name        = "s3-versioning-enabled"
  description = "Checks if Buckets have versioning enabled"

  source {
    owner             = "CUSTOM_LAMBDA"
    source_identifier = module.lambda_module_2.lambda_arn

    source_detail {
      event_source = "aws.config"
      message_type = "ConfigurationItemChangeNotification"
    }
  }

  scope {
    compliance_resource_types = ["AWS::S3::Bucket"]
  }

  /* input_parameters = jsonencode({
  BucketPrefix = "prod-"  # Opcional, personaliza si lo necesitas
}) */

}


/* ------------------------------------------------------------ */
/*                     RULE 3 - IAM USERS
/* ------------------------------------------------------------ */

data "archive_file" "lambda_iam_validation_package" {
  type        = "zip"
  source_file = "./lambda-codes/lambda-iam-validation.py"
  output_path = "${path.root}/lambda-codes/lambda-iam-validation.zip"
}

module "lambda_module_iam" {
  source        = "./modules/mod-lambda"
  function_name = "lambda-existing-iam-users"
  handler       = "lambda-iam-validation.lambda_handler"
  runtime       = "python3.9"
  memory_size   = 128
  timeout       = 10
  source_zip    = "${path.root}/lambda-codes/lambda-iam-validation.zip"
}

resource "aws_config_config_rule" "iam_validation_rule" {
  name        = "existing-iam-users"
  description = "Checks for existing IAM users in the account."

  source {
    owner             = "CUSTOM_LAMBDA"
    source_identifier = module.lambda_module_iam.lambda_arn

    source_detail {
      event_source = "aws.config"
      message_type = "ConfigurationItemChangeNotification"
    }
  }

  depends_on = [
    module.lambda_module_iam
  ]
}

