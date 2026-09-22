# PSG Infrastructure

OpenTofu configuration for PSG's shared AWS infrastructure and IAM Identity
Center in AWS account `538308268352`, primarily in `ca-central-1`.

## Current State

OpenTofu currently manages:

- `PSG-PowerUser`, assigned directly to SCIM-provisioned users through OpenTofu.
- `PSG-Administrator`, assigned directly to Will through OpenTofu.
- `PSG-Ptraynor-Dev-Access`, assigned directly to Will and Patrick through OpenTofu.
- Patrick's hardened Ubuntu 24.04 LTS development host, `ptraynor_dev`, reached exclusively through SSM Session Manager.
- Secrets Manager containers for the Greenplum `gpadmin` and `readonly_user` credentials.

The `ptraynor_dev` host has no inbound security-group rules or SSH key. It has only
the outbound access needed for SSM, DNS, package downloads, and PostgreSQL on
port 5432. Its dedicated security group is authorized on Greenplum and should
be used as the source for port 5432 on the ST:TNG RDS security group.

The following work remains:

- Verify and document organization-wide MFA enforcement in Entra ID.
- Retire the legacy IAM user(s) and associated local profiles after confirming
  that Identity Center access meets operational needs.

The completed Entra ID and SCIM cutover procedure is retained in
[identity-center-scim-migration.md](identity-center-scim-migration.md) as a
historical record.

## Authentication

Microsoft Entra ID owns human identity, sign-in, and provisioning into IAM
Identity Center. OpenTofu owns the AWS permission sets and direct account
assignments for those provisioned users. New users must first be assigned to
the AWS IAM Identity Center enterprise application in Entra, then granted the
appropriate AWS account permission set in `identity-center.tf`.

Human access uses IAM Identity Center temporary credentials. Configure
`psg-power` for routine work; use `psg-admin` for IAM or Identity Center
administration. The AWS access portal is
<https://preyra.awsapps.com/start/>.

```sh
aws sso login --profile psg-power
export AWS_PROFILE=psg-power
aws sts get-caller-identity
```

The provider and backend deliberately contain no profile name so each operator
or automation environment can select its own credentials.

## Access Levels

The permission sets use AWS-managed policies. AWS defines and may update the
underlying permissions; this repository defines who receives them and for how
long.

| Permission set | AWS-managed policy | PSG assignment | Session | Intended use |
| --- | --- | --- | --- | --- |
| `PSG-PowerUser` | [`PowerUserAccess`](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/PowerUserAccess.html) | Will and Patrick | 4 hours | Routine infrastructure work. Broad control of AWS resources, but most IAM, Organizations, and account-management actions are excluded. |
| `PSG-Administrator` | [`AdministratorAccess`](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AdministratorAccess.html) | Will | 1 hour | Short-lived IAM, Identity Center, role, and account administration. Grants all actions on all resources except where another control or root-only restriction applies. |
| `PSG-Ptraynor-Dev-Access` | Inline, host-scoped Session Manager policy | Will and Patrick | 4 hours | Shell, port-forwarding, and start/stop access to `ptraynor_dev` only. |

PowerUser access is not read-only: it can create, modify, and delete most AWS
resources and data. Start with `psg-power`; use `psg-admin` only when the task
requires administrative permissions. AWS's broader job-function descriptions
are documented in [AWS managed policies for job functions](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_job-functions.html).

## OpenTofu Workflow

```sh
export AWS_PROFILE=psg-admin
tofu init
tofu fmt -recursive
tofu validate
tofu plan
```

Do not apply a plan without reviewing every proposed create, change, and
destroy. Repository instructions require explicit approval before `tofu apply`.

## Patrick's Development Host

After Entra provisioning and an AWS account assignment, follow
[setup.md](setup.md) to configure the `psg-power` profile and start a shell
without VPN or SSH:

```sh
aws sso login --profile psg-power
aws ssm start-session \
  --profile psg-power \
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
and runs fixed read-only metadata queries as user `readonly_user`. On the managed
host, the login environment sets `PGSECRET_ID=greenplum/readonly_user`; Boto3
therefore retrieves that secret through the instance role by default. The script
prints the secret name it is using, but never prints its value. The equivalent
explicit command is:

```sh
python ~/test-greenplum.py --secret-id greenplum/readonly_user
```

Connection values can be overridden with the standard `PGHOST`, `PGPORT`,
`PGDATABASE`, and `PGUSER` environment variables. `PGPASSWORD` is supported for
automation but should not be saved in the repository or shell history.

Boto3 remains optional outside the managed host. When `PGSECRET_ID` is unset and
`--secret-id` is omitted, the script uses `PGPASSWORD` when set or prompts for a
password. Use `--prompt-password` to force an interactive prompt even on the
managed host.

For local development or a test through an SSM port-forward, use uv:

```sh
uv sync
uv run scripts/test-greenplum.py --host 127.0.0.1 --port 15432

uv run --extra aws scripts/test-greenplum.py \
  --host 127.0.0.1 \
  --port 15432 \
  --secret-id greenplum/readonly_user
```

Python support tooling uses the standard `pyproject.toml` project metadata and
uv, with dependencies locked in `uv.lock`. The development host intentionally
uses its system Python packages, so uv is not required there.

## Greenplum Secrets

Secrets Manager holds two credential containers:

| Secret name | Database user | Access from `ptraynor_dev` |
| --- | --- | --- |
| `greenplum/gpadmin` | `gpadmin` | No |
| `greenplum/readonly_user` | `readonly_user` | Yes, read-only retrieval |

OpenTofu manages the secret containers and access policy, but deliberately does
not manage secret values because doing so would place the database passwords in
OpenTofu configuration and state. Set and rotate each value directly in Secrets
Manager as JSON with `user` and `password` fields. The test script also accepts
`username` for compatibility. Do not put a password in this repository, a
`.tfvars` file, or a command that will be retained in shell history.

The `ptraynor_dev` instance profile supplies temporary AWS credentials to code
on the host and permits `DescribeSecret` and `GetSecretValue` only for
`greenplum/readonly_user`. No human SSO profile or static AWS credential should
be copied onto the instance. This is an ambient permission: any process running
on the host can potentially retrieve that read-only database password, so the
host is trusted for PSG development code rather than untrusted workloads.

The instance-role restriction is not a restriction on Pat's separate human
access. The AWS-managed `PowerUserAccess` policy currently permits Secrets
Manager actions broadly, so a `PSG-PowerUser` session can retrieve both the
read-only and `gpadmin` secrets. If `gpadmin` must be technically unavailable to
PowerUser holders, add an explicit deny or narrower human permission model; the
host's scoped instance policy alone does not enforce that boundary.

## State Backend

State is stored at:

```text
s3://psg-infra-prod-tfstate/identity-center/prod.tfstate
```

Native S3 state locking and server-side AES-256 encryption are enabled, and
public access is blocked. Bucket versioning is enabled for state recovery.
