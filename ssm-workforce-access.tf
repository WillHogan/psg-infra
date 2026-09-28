resource "aws_ssm_document" "greenplum_port_forwarding" {
  name            = "PSG-Greenplum-PortForwarding"
  document_type   = "Session"
  document_format = "JSON"

  # The target is gpdb01 itself. The database port is fixed rather than exposed
  # as a caller-supplied parameter, so this document cannot forward elsewhere.
  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Direct port forwarding to Greenplum on the target host."
    sessionType   = "Port"
    parameters = {
      localPortNumber = {
        type           = "String"
        description    = "Local client port for the Greenplum tunnel."
        default        = "5432"
        allowedPattern = "^([0-9]|[1-9][0-9]{1,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$"
      }
    }
    properties = {
      type            = "LocalPortForwarding"
      portNumber      = "5432"
      localPortNumber = "{{ localPortNumber }}"
    }
  })

  tags = {
    Name    = "PSG-Greenplum-PortForwarding"
    Purpose = "Greenplum-only SSM port forwarding"
  }
}

# gpdb01 predates this OpenTofu configuration, so manage only the access tag
# needed to select it as the direct Greenplum Session Manager target.
resource "aws_ec2_tag" "greenplum_ssm_access" {
  resource_id = "i-08d909db0106c5d7e"
  key         = "SSMGreenplumAccess"
  value       = "true"
}

resource "aws_ssoadmin_permission_set" "greenplum_access" {
  instance_arn = local.identity_center_instance_arn

  name             = "PSG-Greenplum-Access"
  description      = "Greenplum-only SSM port forwarding without shell or general AWS access."
  session_duration = "PT8H"
}

resource "aws_ssoadmin_permission_set_inline_policy" "greenplum_access" {
  instance_arn       = local.identity_center_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.greenplum_access.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DiscoverManagedNodes"
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances", "ssm:DescribeInstanceInformation", "ssm:DescribeSessions", "ssm:GetConnectionStatus"]
        Resource = "*"
      },
      {
        Sid      = "StartGreenplumTunnelOnTaggedHost"
        Effect   = "Allow"
        Action   = "ssm:StartSession"
        Resource = "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:${var.aws_account_id}:instance/*"
        Condition = {
          StringEquals = {
            "ssm:resourceTag/SSMGreenplumAccess" = "true"
          }
        }
      },
      {
        Sid      = "UseGreenplumOnlySessionDocument"
        Effect   = "Allow"
        Action   = "ssm:StartSession"
        Resource = aws_ssm_document.greenplum_port_forwarding.arn
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

resource "aws_ssoadmin_permission_set" "ssm_shell" {
  instance_arn = local.identity_center_instance_arn

  name             = "PSG-SSM-Shell"
  description      = "Interactive Session Manager shell access to explicitly tagged PSG hosts."
  session_duration = "PT8H"
}

resource "aws_ssoadmin_permission_set_inline_policy" "ssm_shell" {
  instance_arn       = local.identity_center_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.ssm_shell.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DiscoverManagedNodes"
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances", "ssm:DescribeInstanceInformation", "ssm:DescribeSessions", "ssm:GetConnectionStatus"]
        Resource = "*"
      },
      {
        Sid      = "StartShellOnTaggedHost"
        Effect   = "Allow"
        Action   = "ssm:StartSession"
        Resource = "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:${var.aws_account_id}:instance/*"
        Condition = {
          StringEquals = {
            "ssm:resourceTag/SSMShellAccess" = "true"
          }
        }
      },
      {
        Sid      = "UseConfiguredShellDocument"
        Effect   = "Allow"
        Action   = "ssm:StartSession"
        Resource = aws_ssm_document.session_manager_preferences.arn
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
