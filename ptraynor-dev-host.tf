data "aws_partition" "current" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "ptraynor_dev_host" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = ["${var.aws_region}b"]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_ssm_parameter" "ubuntu_2404_arm64_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/arm64/hvm/ebs-gp3/ami-id"
}

resource "aws_security_group" "ptraynor_dev_host" {
  name        = "ptraynor_dev"
  description = "Outbound-only access for Patrick Traynor development host."
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name  = "ptraynor_dev"
    Owner = "patrick.traynor"
  }
}

resource "aws_vpc_security_group_egress_rule" "ptraynor_dev_host_https" {
  security_group_id = aws_security_group.ptraynor_dev_host.id
  description       = "SSM and HTTPS package repositories"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "ptraynor_dev_host_http" {
  security_group_id = aws_security_group.ptraynor_dev_host.id
  description       = "Ubuntu package repositories"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "ptraynor_dev_host_dns_udp" {
  security_group_id = aws_security_group.ptraynor_dev_host.id
  description       = "VPC DNS"
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = "${cidrhost(data.aws_vpc.default.cidr_block, 2)}/32"
}

resource "aws_vpc_security_group_egress_rule" "ptraynor_dev_host_dns_tcp" {
  security_group_id = aws_security_group.ptraynor_dev_host.id
  description       = "VPC DNS fallback"
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = "${cidrhost(data.aws_vpc.default.cidr_block, 2)}/32"
}

resource "aws_vpc_security_group_egress_rule" "ptraynor_dev_host_postgresql" {
  security_group_id = aws_security_group.ptraynor_dev_host.id
  description       = "Greenplum and PostgreSQL-compatible RDS"
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
  cidr_ipv4         = data.aws_vpc.default.cidr_block
}

resource "aws_iam_role" "ptraynor_dev_host" {
  name = "ptraynor_dev"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ptraynor_dev_host_ssm" {
  role       = aws_iam_role.ptraynor_dev_host.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ptraynor_dev_host" {
  name = "ptraynor_dev"
  role = aws_iam_role.ptraynor_dev_host.name
}

resource "aws_instance" "ptraynor_dev_host" {
  ami                         = data.aws_ssm_parameter.ubuntu_2404_arm64_ami.value
  instance_type               = "t4g.medium"
  subnet_id                   = data.aws_subnet.ptraynor_dev_host.id
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ptraynor_dev_host.name
  vpc_security_group_ids      = [aws_security_group.ptraynor_dev_host.id]

  # Access is exclusively through Session Manager; do not attach an SSH key.
  key_name = null

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_size = 16
    volume_type = "gp3"
  }

  user_data = <<-EOT
    #!/bin/bash
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      postgresql-client \
      python3 \
      python3-pip \
      python-is-python3 \
      python3-psycopg2 \
      python3-venv
  EOT

  tags = {
    Name    = "ptraynor_dev"
    Owner   = "patrick.traynor"
    Purpose = "Patrick Traynor development"
  }

  lifecycle {
    # Bootstrap is applied when the disposable host is created. Package changes
    # on a running development host are managed through SSM to avoid restarts.
    ignore_changes = [user_data]
  }
}

# gpdb01 currently allows all TCP traffic from the VPC CIDR. This explicit rule
# records the intended dependency so that broad legacy rule can later be removed.
resource "aws_vpc_security_group_ingress_rule" "greenplum_from_ptraynor_dev_host" {
  security_group_id            = "sg-95be59fd"
  description                  = "Greenplum from ptraynor_dev"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.ptraynor_dev_host.id
}

resource "aws_identitystore_group_membership" "patrick_ptraynor_dev_access" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.ptraynor_dev_access.group_id
  member_id         = aws_identitystore_user.patrick_traynor.user_id
}

resource "aws_ssoadmin_permission_set" "ptraynor_dev_access" {
  instance_arn = local.identity_center_instance_arn

  name             = "PSG-Ptraynor-Dev-Access"
  description      = "Session Manager and lifecycle access to ptraynor_dev."
  session_duration = "PT4H"
}

resource "aws_ssoadmin_permission_set_inline_policy" "ptraynor_dev_access" {
  instance_arn       = local.identity_center_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.ptraynor_dev_access.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DiscoverPtraynorDevHost"
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances", "ssm:DescribeInstanceInformation", "ssm:DescribeSessions", "ssm:GetConnectionStatus"]
        Resource = "*"
      },
      {
        Sid    = "StartPtraynorDevHostSession"
        Effect = "Allow"
        Action = "ssm:StartSession"
        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:${var.aws_account_id}:instance/${aws_instance.ptraynor_dev_host.id}",
          "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}:${var.aws_account_id}:document/SSM-SessionManagerRunShell",
          "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}::document/AWS-StartInteractiveCommand",
          "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}::document/AWS-StartPortForwardingSession",
          "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}::document/AWS-StartPortForwardingSessionToRemoteHost"
        ]
      },
      {
        Sid      = "StartAndStopPtraynorDevHost"
        Effect   = "Allow"
        Action   = ["ec2:StartInstances", "ec2:StopInstances"]
        Resource = "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:${var.aws_account_id}:instance/${aws_instance.ptraynor_dev_host.id}"
      },
      {
        Sid      = "ManageOwnSessions"
        Effect   = "Allow"
        Action   = ["ssm:ResumeSession", "ssm:TerminateSession", "ssmmessages:OpenDataChannel"]
        Resource = "arn:${data.aws_partition.current.partition}:ssm:*:*:session/$${aws:userid}-*"
      }
    ]
  })
}

resource "aws_ssoadmin_account_assignment" "ptraynor_dev_access" {
  depends_on = [aws_ssoadmin_permission_set_inline_policy.ptraynor_dev_access]

  instance_arn       = local.identity_center_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.ptraynor_dev_access.arn

  principal_id   = aws_identitystore_group.ptraynor_dev_access.group_id
  principal_type = "GROUP"

  target_id   = var.aws_account_id
  target_type = "AWS_ACCOUNT"
}
