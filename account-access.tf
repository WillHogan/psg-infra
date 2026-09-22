resource "aws_identitystore_group" "psg_infrastructure" {
  identity_store_id = local.identity_store_id

  display_name = "PSG-Infrastructure"
  description  = "PSG staff responsible for AWS infrastructure operations."

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_identitystore_group_membership" "william_psg_infrastructure" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.psg_infrastructure.group_id
  member_id         = aws_identitystore_user.william_hogan.user_id
}

resource "aws_identitystore_group_membership" "patrick_psg_infrastructure" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.psg_infrastructure.group_id
  member_id         = aws_identitystore_user.patrick_traynor.user_id
}

resource "aws_ssoadmin_permission_set" "power_user" {
  instance_arn = local.identity_center_instance_arn

  name             = "PSG-PowerUser"
  description      = "Routine infrastructure work without IAM, Organizations, or account administration."
  session_duration = "PT4H"
}

resource "aws_ssoadmin_account_assignment" "infrastructure_power_user" {
  instance_arn       = local.identity_center_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.power_user.arn

  principal_id   = aws_identitystore_group.psg_infrastructure.group_id
  principal_type = "GROUP"

  target_id   = var.aws_account_id
  target_type = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_managed_policy_attachment" "power_user" {
  depends_on = [aws_ssoadmin_account_assignment.infrastructure_power_user]

  instance_arn       = local.identity_center_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.power_user.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_ssoadmin_permission_set" "administrator" {
  instance_arn = local.identity_center_instance_arn

  name             = "PSG-Administrator"
  description      = "Short-lived administrative access for IAM and Identity Center management."
  session_duration = "PT1H"
}

resource "aws_ssoadmin_account_assignment" "william_administrator" {
  instance_arn       = local.identity_center_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.administrator.arn

  principal_id   = aws_identitystore_user.william_hogan.user_id
  principal_type = "USER"

  target_id   = var.aws_account_id
  target_type = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_managed_policy_attachment" "administrator" {
  depends_on = [aws_ssoadmin_account_assignment.william_administrator]

  instance_arn       = local.identity_center_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.administrator.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
