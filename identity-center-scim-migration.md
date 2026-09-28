# IAM Identity Center Migration to Entra ID and SCIM

This cutover is complete. The procedure below is retained as a historical
record; do not rerun its state-removal or identity-deletion steps against the
current environment.

This runbook documents the move of user identity ownership to Microsoft Entra ID and SCIM.
Users are assigned individually to the AWS IAM Identity Center enterprise
application in Entra. OpenTofu continues to own permission sets, their policies,
and direct user-to-AWS-account assignments.

At cutover time, the state-removal step had to precede application of the new
configuration. That sequence is documented below for audit and recovery
context; it is not an outstanding task.

## Ownership After Migration

| Object | Owner after migration |
| --- | --- |
| User identity, authentication, MFA, and enterprise-app assignment | Entra ID |
| Identity Center user objects | Entra ID through SCIM |
| Permission sets | OpenTofu |
| Managed and inline permission-set policies | OpenTofu |
| Direct user-to-account assignments | OpenTofu |

OpenTofu does not manage Identity Store users, groups, or memberships. The
`local.identity_center_access` map in `identity-center.tf` is keyed by each
SCIM `UserName`, which must equal the user's Entra UPN and the SAML NameID.
Each map value lists the existing logical permission-set keys assigned to that
user. The account is intentionally implicit because this repository currently
targets only account `538308268352`.

The preserved effective access is:

| SCIM username | Permission sets |
| --- | --- |
| `whogan@preyrasolutions.com` | `PSG-PowerUser`, `PSG-Administrator`, `PSG-Ptraynor-Dev-Access` |
| `patrick.traynor@preyrasolutions.com` | `PSG-PowerUser`, `PSG-Ptraynor-Dev-Access` |

Each direct assignment has a stable OpenTofu key in the form
`username|account-id|permission-set-key`. A mapped user who has not yet been
provisioned by SCIM causes the `aws_identitystore_user` lookup by `UserName` to
fail during planning. No Identity Store user ID is stored in configuration.

## Resource Inventory and Disposition

Relinquish these eight resources to Entra and SCIM by removing them from state
before deleting the old principals:

- `aws_identitystore_user.william_hogan`
- `aws_identitystore_user.patrick_traynor`
- `aws_identitystore_group.psg_infrastructure`
- `aws_identitystore_group.ptraynor_dev_access`
- `aws_identitystore_group_membership.william_psg_infrastructure`
- `aws_identitystore_group_membership.patrick_psg_infrastructure`
- `aws_identitystore_group_membership.william_ptraynor_dev_access`
- `aws_identitystore_group_membership.patrick_ptraynor_dev_access`

Keep these resources under OpenTofu ownership:

- `aws_ssoadmin_permission_set.power_user`
- `aws_ssoadmin_permission_set.administrator`
- `aws_ssoadmin_permission_set.ptraynor_dev_access`
- `aws_ssoadmin_managed_policy_attachment.power_user`
- `aws_ssoadmin_managed_policy_attachment.administrator`
- `aws_ssoadmin_permission_set_inline_policy.ptraynor_dev_access`
- `aws_ssoadmin_account_assignment.user_access` instances generated from the
  access map

The three old assignment resources are replaced by the map-driven direct-user
assignments:

- `aws_ssoadmin_account_assignment.infrastructure_power_user`
- `aws_ssoadmin_account_assignment.william_administrator`
- `aws_ssoadmin_account_assignment.ptraynor_dev_access`

There are no customer-managed policy attachment resources in the current
configuration.

## Maintenance-Window Procedure

Keep root or another non-Identity-Center administrator available throughout.
Pause automatic Entra provisioning while removing the old objects, and do not
use an Identity Center session as the only break-glass path.

1. Check that the selected credentials point at account `538308268352`, then
   initialize and capture the current state inventory and a private backup:

   ```sh
   export AWS_PROFILE=psg-admin
   aws sso login --profile psg-admin
   aws sts get-caller-identity
   tofu init
   tofu state list
   PSG_STATE_BACKUP="$(mktemp /tmp/psg-infra-pre-scim.XXXXXX.tfstate)"
   chmod 600 "$PSG_STATE_BACKUP"
   tofu state pull >"$PSG_STATE_BACKUP"
   echo "$PSG_STATE_BACKUP"
   ```

   The backup may contain sensitive infrastructure data. Do not commit it and
   remove it securely after the migration and state-version recovery window.

2. Remove only the SCIM-owned identity objects from OpenTofu state. This changes
   state ownership but does not delete anything in AWS:

   ```sh
   tofu state rm \
     aws_identitystore_group_membership.william_ptraynor_dev_access \
     aws_identitystore_group_membership.patrick_ptraynor_dev_access \
     aws_identitystore_group_membership.william_psg_infrastructure \
     aws_identitystore_group_membership.patrick_psg_infrastructure \
     aws_identitystore_group.ptraynor_dev_access \
     aws_identitystore_group.psg_infrastructure \
     aws_identitystore_user.william_hogan \
     aws_identitystore_user.patrick_traynor
   ```

   Do not remove permission sets, policy attachments, inline policies, or the
   old account assignments from state.

3. In the Identity Center console, remove the three old account assignments:
   the `PSG-Infrastructure` PowerUser assignment, Will's direct Administrator
   assignment, and the `ptraynor-dev-access` assignment. Then delete the old
   manually provisioned users, groups, and memberships. Removing assignments
   explicitly avoids relying on principal-deletion cascading behavior. Do not
   delete any permission set.

4. In Entra, assign Will and Patrick individually to the AWS IAM Identity
   Center enterprise application. Resume or provoke SCIM provisioning. Verify
   in Identity Center that users with these exact usernames exist:

   - `whogan@preyrasolutions.com`
   - `patrick.traynor@preyrasolutions.com`

   Their internal user IDs will differ from the deleted manual users. Confirm
   the exact `UserName`; email address or display name alone is insufficient.

5. With this final configuration checked out, format, validate, and create a
   saved plan:

   ```sh
   tofu fmt -recursive
   tofu validate
   tofu plan -out=/tmp/psg-infra-scim-migration.tfplan
   tofu show /tmp/psg-infra-scim-migration.tfplan
   ```

   Expect five direct-user account assignments: three for Will and two for
   Patrick. The permission sets and their policy attachments must show no
   replacement or destruction. A failed user lookup means SCIM provisioning is
   incomplete or its `UserName` mapping does not match the UPN; stop and fix
   provisioning rather than hard-coding an internal user ID.

6. Only after reviewing the complete plan and obtaining explicit approval,
   apply that exact saved plan:

   ```sh
   tofu apply /tmp/psg-infra-scim-migration.tfplan
   ```

7. Test SAML login and every intended permission set. Confirm that Will can use
   the one-hour administrator permission set before ending the maintenance
   window. Remove the saved plan and private state backup after the agreed
   recovery period; neither belongs in the repository.

If SCIM provisioning or a data-source lookup fails, stop after step 4. Do not
run OpenTofu from the older configuration: because the eight identity objects
have been removed from state, the older configuration would propose recreating
the manual identities. The final configuration contains no
`aws_identitystore_user`, `aws_identitystore_group`, or
`aws_identitystore_group_membership` resources and therefore cannot recreate
them.
