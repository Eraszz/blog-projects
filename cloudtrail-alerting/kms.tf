##################################################
# KMS Key
##################################################

resource "aws_kms_key" "this" {
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = 30
  is_enabled              = true
  enable_key_rotation     = true
}

resource "aws_kms_alias" "this" {
  name          = format("alias/%s", var.application_name)
  target_key_id = aws_kms_key.this.key_id
}

##################################################
# KMS Key Policy
##################################################

resource "aws_kms_key_policy" "this" {
  key_id = aws_kms_key.this.id
  policy = data.aws_iam_policy_document.key_policy.json
}

data "aws_iam_policy_document" "key_policy" {

  statement {
    effect = "Allow"
    actions = [
      "kms:*"
    ]
    resources = ["*"]
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt"
    ]
    resources = ["*"]
    principals {
      type = "Service"
      identifiers = [
        "cloudtrail.amazonaws.com"
      ]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:DescribeKey"
    ]
    resources = ["*"]
    principals {
      type = "Service"
      identifiers = [
        "cloudtrail.amazonaws.com"
      ]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"

      values = [
        format("arn:aws:cloudtrail:%s:%s:trail/%s", data.aws_region.current.name, data.aws_caller_identity.current.account_id, var.application_name)
      ]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey*"
    ]
    resources = ["*"]
    principals {
      type = "Service"
      identifiers = [
        "cloudtrail.amazonaws.com"
      ]
    }
    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"

      values = [
        format("arn:aws:cloudtrail:*:%s:trail/*", data.aws_caller_identity.current.account_id)
      ]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"

      values = [
        format("arn:aws:cloudtrail:%s:%s:trail/%s", data.aws_region.current.name, data.aws_caller_identity.current.account_id, var.application_name)
      ]
    }
  }
}
