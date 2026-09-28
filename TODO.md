# Infrastructure TODOs

## Complete the PSG PPTX host rename

The host formerly described as Patrick Traynor's development host is now the
PSG PPTX host. OpenTofu resource addresses, tags, documentation, and outputs
use purpose-based `psg_pptx_host` naming, but several physical AWS names remain
legacy names to avoid replacing resources or reprovisioning access:

- IAM role and instance profile: `ptraynor_dev`
- Security group: `ptraynor_dev`
- IAM Identity Center permission set: `PSG-Ptraynor-Dev-Access`
- Security-group description referring to Patrick's development host

Complete these physical renames only through a controlled migration that keeps
the existing EC2 instance and verifies uninterrupted SSM, Greenplum, Secrets
Manager, S3, and IAM Identity Center access. Do not let OpenTofu replace the
instance as part of the rename.

## Make the PSG PPTX host reproducible

The host currently mixes infrastructure managed by OpenTofu with manual
operating-system and application changes. For example, the GitHub Actions
runner and related files have been installed and maintained manually on the
host. Consequently, the EC2 instance cannot currently be recreated safely from
the declared OpenTofu configuration without losing required configuration or
runtime state.

Inventory the manually managed software, users, services, runner registration,
configuration, and persistent data. Move reproducible configuration into an
appropriate automated bootstrap or configuration-management workflow, keep
credentials and runner registration secrets out of OpenTofu state, and define
a tested backup/migration procedure for anything that must remain persistent.
Only remove the instance's `prevent_destroy` and AMI/user-data drift guards once
a replacement host has been built and validated without relying on undocumented
manual steps.
