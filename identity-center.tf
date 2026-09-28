# Entra ID and SCIM own Identity Center users. OpenTofu only looks up those
# users and manages their AWS account assignments.
locals {
  identity_center_access = {
    "whogan@preyrasolutions.com" = {
      permission_sets = toset(["administrator", "power_user", "psg_pptx_host_access"])
    }
    "patrick.traynor@preyrasolutions.com" = {
      permission_sets = toset(["power_user", "psg_pptx_host_access"])
    }
  }

  identity_center_permission_set_arns = {
    administrator        = aws_ssoadmin_permission_set.administrator.arn
    power_user           = aws_ssoadmin_permission_set.power_user.arn
    psg_pptx_host_access = aws_ssoadmin_permission_set.psg_pptx_host_access.arn
  }

  identity_center_account_assignments = merge([
    for username, access in local.identity_center_access : {
      for permission_set_key in access.permission_sets :
      "${username}|${var.aws_account_id}|${permission_set_key}" => {
        username           = username
        target_account_id  = var.aws_account_id
        permission_set_key = permission_set_key
      }
    }
  ]...)
}

data "aws_identitystore_user" "scim" {
  for_each = local.identity_center_access

  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = each.key
    }
  }
}

moved {
  from = aws_ssoadmin_account_assignment.william_administrator
  to   = aws_ssoadmin_account_assignment.user_access["whogan@preyrasolutions.com|538308268352|administrator"]
}

resource "aws_ssoadmin_account_assignment" "user_access" {
  for_each = local.identity_center_account_assignments

  depends_on = [aws_ssoadmin_permission_set_inline_policy.psg_pptx_host_access]

  instance_arn       = local.identity_center_instance_arn
  permission_set_arn = local.identity_center_permission_set_arns[each.value.permission_set_key]

  principal_id   = data.aws_identitystore_user.scim[each.value.username].user_id
  principal_type = "USER"

  target_id   = each.value.target_account_id
  target_type = "AWS_ACCOUNT"
}
