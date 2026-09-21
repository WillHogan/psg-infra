# PSG infrastructure working agreements

## Scope

- This repository manages PSG AWS infrastructure with OpenTofu.
- The AWS account is `538308268352`; the primary Region is `ca-central-1`.
- IAM Identity Center, human access, and the shared state backend are security-sensitive.
- Read `README.md` for the current managed inventory and outstanding work.

## Authentication

- Use temporary IAM Identity Center credentials for human access.
- Use `psg-power` for routine infrastructure work and `psg-admin` only when IAM or Identity Center administration is required.
- Keep provider and backend configuration profile-neutral; select a local profile with `AWS_PROFILE`.
- Never create or commit long-lived AWS access keys, session tokens, passwords, `.env` files, local state, or plan files.
- Do not modify the root user or the legacy `william` IAM user unless the user explicitly requests it.

## Safe workflow

- Inspect existing resources and state before changing configuration.
- Preserve imported resources and unrelated infrastructure.
- Never run `tofu apply`, `tofu destroy`, state mutation commands, or `force-unlock` without explicit user approval.
- After editing OpenTofu, run `tofu fmt -recursive`, `tofu validate`, and a read-only `tofu plan`.
- Summarize every proposed create, change, and destroy before requesting approval to apply.
- Do not edit or replace remote state manually.

## State backend

- Bucket: `psg-infra-prod-tfstate`
- Key: `identity-center/prod.tfstate`
- Region: `ca-central-1`
- Native S3 lockfiles are enabled.
- Bucket versioning is enabled for state recovery.
