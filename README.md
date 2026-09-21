# PSG infrastructure

OpenTofu configuration for PSG's shared AWS infrastructure and IAM Identity
Center. State is stored in `s3://psg-infra-prod-tfstate/identity-center/prod.tfstate`
with native S3 state locking.

## Bootstrap

Use the `psg-too` AWS profile for local commands:

```sh
export AWS_PROFILE=psg-too
tofu init
```

The existing `william.hogan` Identity Center user has been imported. If the
state ever needs to be reconstructed, its import command is:

```sh
tofu import \
  aws_identitystore_user.william_hogan \
  d-9d675c9340/5c9d75b8-c081-7046-ae34-bdc55b33f74c
```

Review the imported configuration before making any changes:

```sh
tofu plan
```

The current user resource prevents accidental deletion while the rest of the
Identity Center configuration is brought under code.

## State bucket requirements

The state bucket should have versioning enabled, public access blocked, and
server-side encryption configured. OpenTofu also needs permission to read and
write both the state object and its adjacent `.tflock` object.
