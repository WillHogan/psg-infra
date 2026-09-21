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

