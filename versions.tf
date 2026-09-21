terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "psg-infra-prod-tfstate"
    key          = "identity-center/prod.tfstate"
    region       = "ca-central-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
