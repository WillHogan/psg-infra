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

# Sessions on ptraynor_dev may retrieve only the read-only database credential.
# The gpadmin credential remains restricted to separately authorized AWS users.
resource "aws_iam_role_policy" "ptraynor_dev_greenplum_readonly_secret" {
  name = "greenplum-readonly-secret"
  role = aws_iam_role.ptraynor_dev_host.id

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
