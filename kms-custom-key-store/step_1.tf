################################################################################
# CloudHSM Cluster and Instance
################################################################################

resource "aws_cloudhsm_v2_cluster" "this" {
  hsm_type   = "hsm1.medium"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = format("%s", var.application_name)
  }
}

resource "aws_cloudhsm_v2_hsm" "primary" {
  subnet_id  = data.aws_subnet.default[data.aws_subnets.default.ids[0]].id
  cluster_id = aws_cloudhsm_v2_cluster.this.id
}


################################################################################
# CloudHSM Cluster Security Group
################################################################################


resource "aws_security_group_rule" "cloudhsm_cluster_cloudhsm_client_egress" {
  security_group_id = aws_cloudhsm_v2_cluster.this.security_group_id

  type        = "egress"
  from_port   = 2223
  to_port     = 2225
  protocol    = "tcp"
  source_security_group_id = aws_security_group.cloudhsm_client.id
}

resource "aws_security_group_rule" "cloudhsm_cluster_cloudhsm_client_ingress" {
  security_group_id = aws_cloudhsm_v2_cluster.this.security_group_id

  type        = "ingress"
  from_port   = 2223
  to_port     = 2225
  protocol    = "tcp"
  source_security_group_id = aws_security_group.cloudhsm_client.id
}

################################################################################
# CloudHSM Client EC2
################################################################################

resource "aws_instance" "this" {
  instance_type          = "t3.micro"
  ami                    = data.aws_ami.amazon_2.id
  subnet_id              = data.aws_subnet.default[data.aws_subnets.default.ids[0]].id
  iam_instance_profile   = aws_iam_instance_profile.this.name
  vpc_security_group_ids = [aws_security_group.cloudhsm_client.id]

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  key_name = var.key_name

  user_data = <<EOF
    #!/bin/bash

    yum update -y
    
    sudo wget https://s3.amazonaws.com/cloudhsmv2-software/CloudHsmClient/EL7/cloudhsm-cli-latest.el7.x86_64.rpm
    sudo yum install ./cloudhsm-cli-latest.el7.x86_64.rpm -y

    sudo /opt/cloudhsm/bin/configure-cli -a ${aws_cloudhsm_v2_hsm.primary.ip_address}       

  EOF

  tags = { "Name" = var.application_name }

}

################################################################################
# Get newest Linux 2 AMI
################################################################################

data "aws_ami" "amazon_2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
  owners = ["amazon"]
}


################################################################################
# EC2 Instance Profile
################################################################################

resource "aws_iam_role" "this" {
  name = "${var.application_name}-cloudhsm-client"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "this" {
  name = "${aws_iam_role.this.name}-ip"
  role = aws_iam_role.this.name
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


################################################################################
# CloudHSM Client Security Group
################################################################################

resource "aws_security_group" "cloudhsm_client" {
  name   = "${var.application_name}-cloudhsm-client"
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "cloudhsm_client_egress" {
  security_group_id = aws_security_group.cloudhsm_client.id

  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = -1
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "cloudhsm_client_ingress_ssh_public" {
  security_group_id = aws_security_group.cloudhsm_client.id

  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = [var.public_ip]
}