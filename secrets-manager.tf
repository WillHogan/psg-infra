resource "aws_secretsmanager_secret" "greenplum_admin" {
  name                    = "greenplum/gpadmin"
  description             = "Greenplum administrator credentials for gpadmin."
  recovery_window_in_days = 30

  tags = {
    Name     = "greenplum/gpadmin"
    Service  = "Greenplum"
    Username = "gpadmin"
  }
}

resource "aws_secretsmanager_secret" "greenplum_readonly" {
  name                    = "greenplum/readonly_user"
  description             = "Greenplum read-only credentials for readonly_user."
  recovery_window_in_days = 30

  tags = {
    Name     = "greenplum/readonly_user"
    Service  = "Greenplum"
    Username = "readonly_user"
  }
}

resource "aws_secretsmanager_secret" "greenplum_pptx_underscored" {
  name                    = "greenplum/psg_pptx"
  description             = "Greenplum credentials for the psg_pptx report job user."
  recovery_window_in_days = 30

  tags = {
    Name     = "greenplum/psg_pptx"
    Service  = "Greenplum"
    Username = "psg_pptx"
  }
}

# Sessions on the PSG PPTX host may retrieve the read-only and PPTX job credentials.
# The gpadmin credential remains restricted to separately authorized AWS users.
resource "aws_iam_role_policy" "psg_pptx_host_greenplum_readonly_secret" {
  name = "greenplum-readonly-secret"
  role = aws_iam_role.psg_pptx_host.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadGreenplumReadonlySecret"
      Effect   = "Allow"
      Action   = ["secretsmanager:DescribeSecret", "secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.greenplum_readonly.arn
    }]
  })
}

resource "aws_iam_role_policy" "psg_pptx_host_greenplum_pptx_underscored_secret" {
  name = "greenplum-psg-pptx-secret"
  role = aws_iam_role.psg_pptx_host.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadGreenplumPptxSecret"
      Effect   = "Allow"
      Action   = ["secretsmanager:DescribeSecret", "secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.greenplum_pptx_underscored.arn
    }]
  })
}
