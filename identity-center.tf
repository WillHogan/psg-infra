resource "aws_identitystore_user" "william_hogan" {
  identity_store_id = local.identity_store_id

  user_name    = "william.hogan"
  display_name = "Will Hogan"

  name {
    given_name  = "Will"
    family_name = "Hogan"
  }

  emails {
    value   = "whogan@preyrasolutions.com"
    type    = "work"
    primary = true
  }

  lifecycle {
    # Protect this existing administrator while the Identity Center
    # configuration is being brought under code.
    prevent_destroy = true

  }
}

resource "aws_identitystore_group" "analytics_ssm_access" {
  identity_store_id = local.identity_store_id

  display_name = "analytics-ssm-access"
  description  = "For access to SSM forwarding to the database."

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_identitystore_group_membership" "william_analytics_ssm_access" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.analytics_ssm_access.group_id
  member_id         = aws_identitystore_user.william_hogan.user_id
}
