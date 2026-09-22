resource "aws_ssoadmin_permission_set" "power_user" {
  instance_arn = local.identity_center_instance_arn

  name             = "PSG-PowerUser"
  description      = "Routine infrastructure work without IAM, Organizations, or account administration."
  session_duration = "PT4H"
}

resource "aws_ssoadmin_managed_policy_attachment" "power_user" {
  depends_on = [aws_ssoadmin_account_assignment.user_access]

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

resource "aws_ssoadmin_managed_policy_attachment" "administrator" {
  depends_on = [aws_ssoadmin_account_assignment.user_access]

  instance_arn       = local.identity_center_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.administrator.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
