################################################################################
# EventBrdige Glue ETL Raw->Clean Rule & Target
################################################################################

resource "aws_cloudwatch_event_rule" "glue_etl_raw_clean" {
  name        = format("%s-%s", var.application_name, "glue-etl-raw-clean")
  description = "Trigger Glue Init script after DMS Full Load and Glue Incremental after CDC"
  role_arn    = aws_iam_role.eventbridge.arn

  event_pattern = jsonencode({
    "source" : ["aws.s3"],
    "detail-type" : ["Object Created"],
    "detail" : {
      "bucket" : {
        "name" : [module.s3["raw-zone"].id]
      },
      "object" : {
        "key" : [{
          "wildcard" : "*.csv"
        }]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "glue_etl_raw_clean" {
  target_id = format("%s-%s", var.application_name, "glue-etl-raw-clean")
  arn       = aws_sfn_state_machine.glue_etl_raw_clean.arn
  role_arn  = aws_iam_role.eventbridge.arn

  rule = aws_cloudwatch_event_rule.glue_etl_raw_clean.name

  input_transformer {
    input_paths = {
      "bucket_name" : "$.detail.bucket.name",
      "object_key" : "$.detail.object.key"
    }
    input_template = <<EOF
    {
    "bucket_name": <bucket_name>,
    "object_key": <object_key>,
    "crawler_prefix": "raw-zone"
    }
    EOF
  }
}


################################################################################
# EventBrdige Glue ETL Clean->Refined Rule & Target
################################################################################

resource "aws_cloudwatch_event_rule" "glue_etl_clean_refined" {
  name        = format("%s-%s", var.application_name, "glue-etl-clean-refined")
  description = "Trigger Glue Consolidate script after data has been added to cleaned zone S3 bucket"
  role_arn    = aws_iam_role.eventbridge.arn

  schedule_expression = "cron(0 0 * * ? *)"
}

resource "aws_cloudwatch_event_target" "glue_etl_clean_refined" {
  target_id = format("%s-%s", var.application_name, "glue-etl-clean-refined")
  arn       = aws_glue_workflow.glue_consolidate.arn
  role_arn  = aws_iam_role.eventbridge.arn

  rule = aws_cloudwatch_event_rule.glue_etl_clean_refined.name
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
    sid = "eventBridge"
    actions = [
      "states:StartExecution"
    ]
    resources = [aws_sfn_state_machine.glue_etl_raw_clean.arn]
  }

  statement {
    sid = "iam"
    actions = [
      "iam:PassRole"
    ]
    resources = [aws_iam_role.sfn.arn]
  }

    statement {
    sid = "glue"
    actions = [
      "glue:notifyEvent"
    ]
    resources = [aws_glue_workflow.glue_consolidate.arn]
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
