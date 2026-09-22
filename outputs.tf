output "aws_account_id" {
  description = "AWS account selected by the provider."
  value       = data.aws_caller_identity.current.account_id
}

output "identity_center_instance_arn" {
  description = "ARN of the existing IAM Identity Center instance."
  value       = local.identity_center_instance_arn
}

output "identity_store_id" {
  description = "ID of the existing IAM Identity Center identity store."
  value       = local.identity_store_id
}

output "ptraynor_dev_instance_id" {
  description = "Instance ID to use with AWS Systems Manager Session Manager."
  value       = aws_instance.ptraynor_dev_host.id
}

output "ptraynor_dev_security_group_id" {
  description = "Authorize this security group as the source on the ST:TNG RDS security group."
  value       = aws_security_group.ptraynor_dev_host.id
}
