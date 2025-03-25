
/*
################################################################################
# Second CLoudHSM Instance
################################################################################

resource "aws_cloudhsm_v2_hsm" "secondary" {
  subnet_id  = data.aws_subnet.default[data.aws_subnets.default.ids[1]].id
  cluster_id = aws_cloudhsm_v2_cluster.this.id
}

##################################################
# KMS Custom Key Store
##################################################

resource "aws_kms_custom_key_store" "this" {
  cloud_hsm_cluster_id  = aws_cloudhsm_v2_cluster.this.id
  custom_key_store_name = var.application_name
  key_store_password    = var.kms_user_password

  trust_anchor_certificate = file("${path.module}/certs/customerCA.crt")

  depends_on = [ aws_cloudhsm_v2_hsm.secondary ]
}
*/