variable "aws_region" {
  description = "AWS Region containing the IAM Identity Center instance."
  type        = string
  default     = "ca-central-1"
}

variable "aws_account_id" {
  description = "AWS account that owns the PSG IAM Identity Center instance."
  type        = string
  default     = "538308268352"
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
}

data "aws_caller_identity" "current" {}

data "aws_ssoadmin_instances" "this" {}

locals {
  identity_center_instance_arn = one(data.aws_ssoadmin_instances.this.arns)
  identity_store_id            = one(data.aws_ssoadmin_instances.this.identity_store_ids)
}

check "expected_identity_store" {
  assert {
    condition     = local.identity_store_id == "d-9d675c9340"
    error_message = "The active AWS credentials resolved a different IAM Identity Center identity store."
  }
}

