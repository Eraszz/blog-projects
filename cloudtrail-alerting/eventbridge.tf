################################################################################
# EventBrdige Rule
################################################################################

resource "aws_cloudwatch_event_rule" "monitor_iam_api_calls" {
  name        = format("%s-%s", var.application_name, "create-delete-iam-user")
  description = "Trigger rule when defined IAM events are detected."
  role_arn    = aws_iam_role.eventbridge.arn

  event_pattern = jsonencode({
    "source" : ["aws.iam"],
    "detail-type" : [
      "AWS API Call via CloudTrail",
    "AWS Console Action via CloudTrail"],
    "detail" : {
      "eventSource" : ["iam.amazonaws.com"],
      "eventName" : var.iam_events
    }
  })
}

resource "aws_cloudwatch_event_target" "monitor_iam_api_calls" {
  target_id = format("%s-%s", var.application_name, "create-delete-iam-user")
  arn       = aws_lambda_function.this.arn
  role_arn  = aws_iam_role.eventbridge.arn

  rule = aws_cloudwatch_event_rule.monitor_iam_api_calls.name
}

resource "aws_cloudwatch_event_rule" "root_user" {
  name        = format("%s-%s", var.application_name, "root-user")
  description = "Trigger rule when IAM Root user performs actions"
  role_arn    = aws_iam_role.eventbridge.arn

  event_pattern = jsonencode({
    "detail-type" : [
      "AWS API Call via CloudTrail",
    "AWS Console Action via CloudTrail"],
    "detail" : {
      "userIdentity" : {
        "type" : [
          "Root"
        ]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "root_user" {
  target_id = format("%s-%s", var.application_name, "root-user")
  arn       = aws_lambda_function.this.arn
  role_arn  = aws_iam_role.eventbridge.arn

  rule = aws_cloudwatch_event_rule.root_user.name
}

################################################################################
# IAM role for EventBrdige
################################################################################

resource "aws_iam_role" "eventbridge" {
  name = format("%s-%s", var.application_name, "eventbridge")

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      },
    ]
  })
}

data "aws_iam_policy_document" "eventbridge" {

  statement {
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = [
      aws_lambda_function.this.arn
    ]
  }
}

resource "aws_iam_policy" "eventbridge" {
  name   = format("%s-%s", var.application_name, "eventbridge")
  policy = data.aws_iam_policy_document.eventbridge.json
}

resource "aws_iam_role_policy_attachment" "eventbridge" {
  role       = aws_iam_role.eventbridge.name
  policy_arn = aws_iam_policy.eventbridge.arn
}


