# PSG infrastructure

OpenTofu configuration for PSG's shared AWS infrastructure and IAM Identity
Center in AWS account `538308268352`, primarily in `ca-central-1`.

## Current state

OpenTofu currently manages:

- The existing Identity Center user.
- The `PSG-Infrastructure` group and membership.
- `PSG-PowerUser`, assigned to the infrastructure group for routine work.
- `PSG-Administrator`, assigned directly to Will for short-lived administrative work.
- The existing `analytics-ssm-access` group and Will's membership.

The `analytics-ssm-access` group has no AWS account assignment or permission
set yet. It is retained for possible SSM port-forwarding access to databases.

The following work remains:

- Create new Identity Center users and add their intended access.
- Verify and document organization-wide MFA enforcement.
- Define the SSM access policy and account assignment if VPN access is replaced.
- Retire the legacy IAM user(s) and associated local profiles only after the transition is complete.

## Authentication

Human access uses IAM Identity Center temporary credentials. The verified
administrative profile is `psg-admin`; configure `psg-power` for routine work.

```sh
aws sso login --profile psg-admin
export AWS_PROFILE=psg-admin
aws sts get-caller-identity
```

The provider and backend deliberately contain no profile name so each operator
or automation environment can select its own credentials.

## Access levels

The permission sets use AWS-managed policies. AWS defines and may update the
underlying permissions; this repository defines who receives them and for how
long.

| Permission set | AWS-managed policy | PSG assignment | Session | Intended use |
| --- | --- | --- | --- | --- |
| `PSG-PowerUser` | [`PowerUserAccess`](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/PowerUserAccess.html) | `PSG-Infrastructure` group | 4 hours | Routine infrastructure work. Broad control of AWS resources, but most IAM, Organizations, and account-management actions are excluded. |
| `PSG-Administrator` | [`AdministratorAccess`](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AdministratorAccess.html) | Direct user assignment | 1 hour | Short-lived IAM, Identity Center, role, and account administration. Grants all actions on all resources except where another control or root-only restriction applies. |

PowerUser access is not read-only: it can create, modify, and delete most AWS
resources and data. Start with `psg-power`; use `psg-admin` only when the task
requires administrative permissions. AWS's broader job-function descriptions
are documented in [AWS managed policies for job functions](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_job-functions.html).

## OpenTofu workflow

```sh
export AWS_PROFILE=psg-admin
tofu init
tofu fmt -recursive
tofu validate
tofu plan
```

Do not apply a plan without reviewing every proposed create, change, and
destroy. Repository instructions require explicit approval before `tofu apply`.

## State backend

State is stored at:

```text
s3://psg-infra-prod-tfstate/identity-center/prod.tfstate
```

Native S3 state locking and server-side AES-256 encryption are enabled, and
public access is blocked. Bucket versioning is enabled for state recovery.

## Imported-resource recovery

These commands are recorded only for reconstructing state if it is lost; do
not run them against healthy state.

```sh
tofu import \
  aws_identitystore_user.william_hogan \
  d-9d675c9340/5c9d75b8-c081-7046-ae34-bdc55b33f74c

tofu import \
  aws_identitystore_group.analytics_ssm_access \
  d-9d675c9340/bc0d1508-9061-701b-9a6a-055b570add49

tofu import \
  aws_identitystore_group_membership.william_analytics_ssm_access \
  d-9d675c9340/7c4d9508-2061-7035-e56b-f588aec18d5a
```
