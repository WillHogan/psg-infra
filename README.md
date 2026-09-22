# PSG infrastructure

OpenTofu configuration for PSG's shared AWS infrastructure and IAM Identity
Center in AWS account `538308268352`, primarily in `ca-central-1`.

## Current state

OpenTofu currently manages:

- The Will Hogan and Patrick Traynor Identity Center users.
- The `PSG-Infrastructure` group and their memberships.
- `PSG-PowerUser`, assigned to the infrastructure group for routine work.
- `PSG-Administrator`, assigned directly to Will for short-lived administrative work.
- The `ptraynor-dev-access` group and Will and Patrick's memberships.
- `PSG-Ptraynor-Dev-Access`, assigned to the dedicated host access group.
- Patrick's hardened Ubuntu 24.04 LTS development host, `ptraynor_dev`, reached exclusively through SSM Session Manager.
- Secrets Manager containers for the Greenplum `gpadmin` and `readonly_user` credentials.

The `ptraynor_dev` host has no inbound security-group rules or SSH key. It has only
the outbound access needed for SSM, DNS, package downloads, and PostgreSQL on
port 5432. Its dedicated security group is authorized on Greenplum and should
be used as the source for port 5432 on the ST:TNG RDS security group.

The following work remains:

- Verify and document organization-wide MFA enforcement.
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
| `PSG-Ptraynor-Dev-Access` | Inline, host-scoped Session Manager policy | `ptraynor-dev-access` group | 4 hours | Shell, port-forwarding, and start/stop access to `ptraynor_dev` only. |

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

## Patrick's development host

After configuring an IAM Identity Center profile for
`PSG-Ptraynor-Dev-Access`, start a shell without VPN or SSH:

```sh
aws sso login --profile psg-ptraynor-dev
aws ssm start-session \
  --profile psg-ptraynor-dev \
  --region ca-central-1 \
  --target "$(tofu output -raw ptraynor_dev_instance_id)"
```

The Ubuntu host has Python 3, a `python` alias, `pip`, `venv`, Psycopg 2, and
`psql` installed. Session Manager starts Linux sessions as login Bash shells in
the user's home directory. The ST:TNG RDS
security group must allow PostgreSQL port 5432 from the security group emitted
by `tofu output -raw ptraynor_dev_security_group_id`.

Using the Greenplum `readonly_user` login, test connectivity from the
host without putting its password in shell history:

```sh
python ~/test-greenplum.py
```

The script connects to `gpdb-priv.preyrasolutions.com:5432`, database `psg`,
and runs fixed read-only metadata queries as user `readonly_user`. Connection values
can be overridden with the standard `PGHOST`, `PGPORT`, `PGDATABASE`, and
`PGUSER` environment variables. `PGPASSWORD` is supported for automation but
should not be saved in the repository or shell history.

For local development or a test through an SSM port-forward, use uv:

```sh
uv sync
uv run scripts/test-greenplum.py --host 127.0.0.1 --port 15432
```

Python support tooling uses the standard `pyproject.toml` project metadata and
uv, with dependencies locked in `uv.lock`. The development host intentionally
uses its system Python packages, so uv is not required there.

## Greenplum secrets

Secrets Manager holds two credential containers:

| Secret name | Database user | Access from `ptraynor_dev` |
| --- | --- | --- |
| `greenplum/gpadmin` | `gpadmin` | No |
| `greenplum/readonly_user` | `readonly_user` | Yes, read-only retrieval |

OpenTofu manages the secret containers and access policy, but deliberately does
not manage secret values because doing so would place the database passwords in
OpenTofu configuration and state. After applying the infrastructure changes,
set each value directly in Secrets Manager as JSON with `username` and
`password` fields. Do not put a password in this repository, a `.tfvars` file,
or a command that will be retained in shell history.

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
  aws_identitystore_group.ptraynor_dev_access \
  d-9d675c9340/bc0d1508-9061-701b-9a6a-055b570add49

tofu import \
  aws_identitystore_group_membership.william_ptraynor_dev_access \
  d-9d675c9340/7c4d9508-2061-7035-e56b-f588aec18d5a
```
