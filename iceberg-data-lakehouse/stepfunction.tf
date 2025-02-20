##################################################
# Step-Function
##################################################

resource "aws_sfn_state_machine" "glue_etl_raw_clean" {
  name     = format("%s-%s", var.application_name, "glue-etl-raw-clean")
  role_arn = aws_iam_role.sfn.arn

  definition = templatefile("${path.module}/src/stepfunction/glue_etl_raw_clean.json", {
    glue_init_job_name        = aws_glue_job.glue_init.name
    glue_incremental_job_name = aws_glue_job.glue_incremental.name
  })
}

################################################################################
# IAM Role for Step-Function
################################################################################

resource "aws_iam_role" "sfn" {
  name = format("%s-%s", var.application_name, "sfn")

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      },
    ]
  })
}

data "aws_iam_policy_document" "sfn" {
  statement {
    actions = [
      "glue:StartCrawler",
      "glue:GetCrawler"
    ]

    resources = [for k, v in aws_glue_crawler.raw : v.arn]
  }

  statement {
    actions = [
      "glue:StartJobRun"
    ]

    resources = [
      aws_glue_job.glue_init.arn,
    aws_glue_job.glue_incremental.arn]
  }

}

resource "aws_iam_policy" "sfn" {
  name   = format("%s-%s", var.application_name, "sfn")
  policy = data.aws_iam_policy_document.sfn.json
}

resource "aws_iam_role_policy_attachment" "sfn" {
  role       = aws_iam_role.sfn.name
  policy_arn = aws_iam_policy.sfn.arn
}
