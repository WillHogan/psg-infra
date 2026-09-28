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

output "psg_pptx_host_instance_id" {
  description = "Instance ID to use with AWS Systems Manager Session Manager."
  value       = aws_instance.psg_pptx_host.id
}

output "psg_pptx_host_security_group_id" {
  description = "Authorize this security group as the source on the ST:TNG RDS security group."
  value       = aws_security_group.psg_pptx_host.id
}

output "psg_dataset_outputs_bucket_name" {
  description = "S3 bucket used by the PSG PPTX generation workflow."
  value       = aws_s3_bucket.psg_dataset_outputs.id
}

output "secure_transfer_legacy_bucket_name" {
  description = "S3 bucket containing the read-only legacy Secure Transfer file mirror."
  value       = aws_s3_bucket.secure_transfer_legacy.id
}

output "secure_transfer_legacy_sync_instance_profile_name" {
  description = "Instance profile to associate with the existing Secure Transfer EC2 instance."
  value       = aws_iam_instance_profile.secure_transfer_legacy_sync.name
}

output "greenplum_admin_secret_name" {
  description = "Secrets Manager name for the gpadmin credentials."
  value       = aws_secretsmanager_secret.greenplum_admin.name
}

output "greenplum_readonly_secret_name" {
  description = "Secrets Manager name for the readonly_user credentials."
  value       = aws_secretsmanager_secret.greenplum_readonly.name
}

output "greenplum_pptx_secret_name" {
  description = "Secrets Manager name for the psg_pptx report job credentials."
  value       = aws_secretsmanager_secret.greenplum_pptx_underscored.name
}
