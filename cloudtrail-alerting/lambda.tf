################################################################################
# Lambda
################################################################################

resource "aws_lambda_function" "this" {
  function_name = var.application_name
  role          = aws_iam_role.lambda.arn

  filename         = data.archive_file.this.output_path
  handler          = "index.lambda_handler"
  runtime          = "python3.13"
  source_code_hash = data.archive_file.this.output_base64sha256

  timeout     = 10
  memory_size = 512

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.this.arn
    }
  }
}

data "archive_file" "this" {
  type        = "zip"
  source_file = "${path.module}/src/index.py"
  output_path = "${path.module}/src/python.zip"
}


################################################################################
# Cloudwatch Log Group
################################################################################

resource "aws_cloudwatch_log_group" "this" {
  name = "/aws/lambda/${aws_lambda_function.this.function_name}"
}


################################################################################
# Lambda Resource Policy Permissions
################################################################################

resource "aws_lambda_permission" "monitor_iam_api_calls" {
  function_name = aws_lambda_function.this.function_name

  action     = "lambda:InvokeFunction"
  principal  = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.monitor_iam_api_calls.arn
}

resource "aws_lambda_permission" "root_user" {
  function_name = aws_lambda_function.this.function_name

  action     = "lambda:InvokeFunction"
  principal  = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.root_user.arn
}

################################################################################
# Lambda Permissions
################################################################################

resource "aws_iam_role" "lambda" {
  name = format("%s-%s", var.application_name, "lambda")

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

data "aws_iam_policy_document" "lambda" {
  statement {
    actions = [
      "sns:publish"
    ]
    resources = [
      aws_sns_topic.this.arn
    ]
  }

  statement {
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt"
    ]
    resources = [
      aws_kms_key.this.arn
    ]
  }
}

resource "aws_iam_policy" "lambda" {
  name   = format("%s-%s", var.application_name, "lambda")
  policy = data.aws_iam_policy_document.lambda.json
}

resource "aws_iam_role_policy_attachment" "lambda" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda.arn
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}