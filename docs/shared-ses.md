# Shared SES feedback capture

Deployed and verified October 2, 2026 for account `538308268352`, Region `ca-central-1`.
The scope is durable capture of bounce and complaint events while application
behavior is deferred. The authorized applies persisted eight imports, created
six capture resources, and then disabled domain feedback forwarding after two
authorized simulator sends were verified in SQS. No DNS mutation was performed.
The earlier optional operator-email design is replaced by
SES → SNS → SQS. Custom MAIL FROM was initially deferred from that minimal
capture change, then separately authorized; see the authentication section below.

## Live state and shared ownership

The AWS Agent Toolkit SES guidance and AWS MCP server were used to recheck the
account, identities, configuration set, and SNS/SQS inventory with the
`PSG-PowerUser` session for `whogan@preyrasolutions.com`.

| Item | Rechecked state |
| --- | --- |
| Production access and sending | Enabled; account `HEALTHY` |
| Domain identity | `preyrasolutions.com`, verified, DKIM signing enabled and `SUCCESS` |
| Identity default configuration set | `psg-transactional` |
| Configuration set | Sending and reputation metrics enabled; enabled bounce/complaint SNS destination |
| Domain feedback forwarding | Disabled after verified capture |
| Account suppression | Existing `BOUNCE` and `COMPLAINT` preferences enabled |
| Custom MAIL FROM | `bounce.preyrasolutions.com`, status `SUCCESS`; fallback `USE_DEFAULT_VALUE` |
| Capture resources | SNS topic and SQS queue `psg-ses-feedback`; confirmed raw SQS subscription |
| Other verified identity | `whogan@preyrasolutions.com`; no explicit configuration set returned |

`ses.tf` manages the new `psg-transactional` configuration set and seven adopted
resources: the domain identity,
domain forwarding preference, existing account suppression preferences, three
successful DKIM CNAME sets, and existing DMARC TXT set. Imports retain the
successful DKIM attributes/tokens. The initially imported
`my-first-configuration-set` was retired after the verified migration below.
No new suppression behavior is implemented. No role, SMTP credential, or static
AWS key is introduced. ST:TNG owns its existing identity-scoped send permission.

The existing public Route 53 zone `Z2NR9N1YFPSN3U` is referenced as a data source,
not recreated or adopted wholesale. DKIM/DMARC records retain their values and
TTL 300. Root Microsoft 365 MX/SPF, root verification TXT values, old `_amazonses`
verification TXT, and unrelated infrastructure remain unchanged. The existing
DMARC policy is `v=DMARC1; p=none;`.

## Capture path

`ses-feedback.tf` declares six resources:

1. Standard SNS topic `psg-ses-feedback`.
2. Topic policy allowing only SES publication from this account and the shared
   configuration set ARN.
3. Standard SQS queue `psg-ses-feedback`, encrypted with SQS-managed encryption,
   with 20-second long polling and the maximum 14-day retention.
4. Queue policy allowing `sqs:SendMessage` only from SNS with this topic ARN and
   account as source conditions.
5. An SQS subscription with raw message delivery enabled and no filter.
6. An enabled SES configuration-set destination matching only `BOUNCE` and
   `COMPLAINT`.

The event destination depends on both publish policies and the queue subscription.
Queue and topic have destroy protection. There is no application consumer or
consumer permission grant. No delivery/open/click events, email subscriptions,
application retry policy, suppression handling, UI, or notification-state changes
are included. Existing SES reputation metrics are preserved.

SQS retains an accepted message for at most **14 days**, then it expires even
without a consumer. This is a durable buffer, not indefinite archival storage.
Plan a consumer or separately approved archival path before the first retained
events expire if longer history is required. No application retry or redrive
configuration is introduced; AWS's built-in transport behavior remains in place.
[SQS retention limits](https://aws.amazon.com/sqs/faqs/).

Outputs expose `ses_configuration_set_name`, `ses_identity_arn`,
`ses_feedback_topic_arn`, `ses_feedback_queue_arn`, and `ses_feedback_queue_url`.

## Application send coverage

The domain default assigns `psg-transactional` to outbound mail from
`preyrasolutions.com`. The selected generic From is
`no-reply@preyrasolutions.com`; application-specific senders such as
`securetransfer@preyrasolutions.com` are encouraged. Neither address has a
separate SES identity in the current inventory. Human replies use an explicit
monitored Reply-To when the application supports them; the no-reply address
does not need a human-monitored inbox for sending.

Read-only inspection of the sibling ST:TNG checkout found one production SES
send call in `internal/notification/ses.go`. Both setup and staff-upload mail
use this adapter through `notification.Mailer`; it does not set
`ConfigurationSetName`, so it uses the sending identity's default. Production
SMTP is rejected in `cmd/sttng/main.go`. No application code changes are needed
for the selected senders to use the shared default, and no sibling files were
modified.

The default is not a global enforcement policy. A more-specific identity or
explicit per-send override can change configuration-set selection. Before
forwarding cutover, verify every deployed application's sender, Region and send
path. Require this configuration set on every send, through the identity default
or explicit selection; new sender identities and overrides must preserve that
contract. The separately verified `whogan` identity is not adopted or changed by
this application-mail slice. Simulator API requests matching the current
adapter's default selection verified both selected senders. They used the
PowerUser session, not the deployed application's runtime role or UI; no live
application workflow test or deployment configuration change was performed.
[SES configuration sets](https://docs.aws.amazon.com/ses/latest/dg/using-configuration-sets.html),
[identity inheritance](https://docs.aws.amazon.com/ses/latest/dg/creating-identities.html).

## Queue and event contract

For bounce/complaint events, SQS `Body` is the original SES event-publishing JSON.
Raw SNS delivery strips
the SNS notification wrapper; there is no nested SNS `Message` string and no
Watermill envelope yet.
[SNS raw delivery](https://docs.aws.amazon.com/sns/latest/dg/sns-large-payload-raw-message-delivery.html).

Setup verification also observed a 65-character non-JSON service validation
message in the queue. A future consumer must distinguish such control messages
from provider events; do not assume every message body decodes as SES JSON.
The validation message and both simulator events were retained, not deleted.

| Field | Consumer contract |
| --- | --- |
| `eventType` | `Bounce` or `Complaint` (payload casing differs from the uppercase destination settings) |
| `mail.messageId` | SES-assigned outbound message ID; distinguish it from the SQS message ID |
| `mail.sendingAccountId`, `mail.sourceArn` | Sending account/identity context |
| `mail.destination`, `mail.tags` | Original recipient context and sending tags, when provided |
| `bounce` | Bounce details, including feedback ID, timestamp, type/subtype and bounced recipients |
| `complaint` | Complaint details, including feedback ID, timestamp and potential complained recipients |

Preserve the provider payload and tolerate additional or absent optional fields.
Do not equate complaint recipient candidates with a reliably identified human
complainant. Event publishing reports permanent bounces and transient failures
after SES stops its own delivery attempts, rather than every transient attempt.
[SES event schema](https://docs.aws.amazon.com/ses/latest/dg/event-publishing-retrieving-sns-contents.html).

Standard SNS/SQS delivery can duplicate and reorder messages. The future consumer
must be idempotent; use the provider feedback ID with event type/account context
as the basis for deduplication, not the SQS receipt handle. It should delete a
message only after its durable ingestion succeeds. No messages are currently
received or deleted by the application. The payload can contain addresses,
headers, subjects and diagnostic details; avoid logging complete bodies and
keep future consumer IAM scoped to this queue.

## Forwarding cutover and verification

The initial provisioning used `ses_feedback_capture_verified=false`, retaining
forwarding until both event types were observed in SQS. It now defaults to
`true`, with the verification evidence below, so routine plans preserve the
completed cutover. Set it to `false` through a reviewed apply to restore
forwarding during repair. This is an operator attestation, not an automated
proof; a future replacement path must undergo the following checks again.

1. Review the full fresh plan and obtain explicit approval to apply capture
   infrastructure and imports. No DNS writes are proposed.
2. Read back the destination, SNS policy, SQS policy/subscription, raw-delivery
   setting, queue retention/encryption, and domain default configuration set.
3. Confirm deployed application send coverage as described above, including
   any separately verified sender identity. Keep forwarding enabled meanwhile.
4. Obtain separate explicit authorization for bounce and complaint simulator
   sends through the application send path. Check that both SES event types
   reach the queue and correlate them using SES message IDs. Any authorized
   diagnostic receive changes visibility temporarily; do not delete or purge
   retained messages during verification.
5. Record verification evidence, set `ses_feedback_capture_verified=true` in
   the deployment inputs, rerun and review the plan, and obtain explicit apply
   approval. The intended cutover is only domain forwarding `true → false`.
6. Read back forwarding and capture configuration after cutover. Re-enable
   forwarding through a reviewed apply if capture fails. Check retention age
   while a consumer remains deferred.

## Validation and plan results

OpenTofu `1.12.6`, locked AWS provider `6.65.0`:

```text
tofu fmt -recursive                         PASS
AWS_PROFILE=psg-admin tofu validate          PASS
AWS_PROFILE=psg-admin tofu plan -lock=false  PASS
Plan: 8 to import, 6 to add, 0 to change, 0 to destroy.
```

A separate hypothetical read-only plan with
`TF_VAR_ses_feedback_capture_verified=true` also passed: **8 imports, 6 additions,
1 change, 0 destroys**. The sole update was domain email forwarding `true → false`.
This validates the proposed cutover switch, not end-to-end delivery; the flag
was not persisted or applied. After provisioning and verification, the cutover
plan should contain only that one update because imports/resources will exist.

The authorized provisioning apply completed with **8 imported, 6 added,
0 changed, 0 destroyed**. The subsequent forwarding cutover plan/apply contained
only **0 added, 1 changed, 0 destroyed**: domain email forwarding `true → false`.
The final full refreshed plan reported **No changes: infrastructure matches the
configuration** after cutover.
Authentication DNS, Microsoft 365 and unrelated infrastructure had no updates
or destroys. The previous optional email-alert plan and MAIL FROM plan are
superseded by this scope. `psg-admin` is needed for existing IAM reads during
the full refresh; routine AWS MCP checks used `psg-power`. Provider/backend
configuration remains profile-neutral. Read-only plans did not persist state or
create lockfiles; the authorized applies used normal remote-state locking and
persisted resource ownership. No local state or executable plan was saved.

### Capture verification evidence

At approximately 20:34 EDT on October 2, two authorized SES simulator requests
were sent without `ConfigurationSetName`, matching the current ST:TNG adapter's
identity-default behavior:

| Event | Sender | SES message ID | SQS message ID |
| --- | --- | --- | --- |
| Bounce | `no-reply@preyrasolutions.com` | `010d01a0ff2f424c-bdd5a79d-89b0-4c42-a27b-1c847e8e4540-000000` | `312bffa0-adc1-4ee9-9c5b-52362a6122f4` |
| Complaint | `securetransfer@preyrasolutions.com` | `010d01a0ff2f7930-7baef02c-bd7e-4d19-a124-58ef16314403-000000` | `f86ef55b-56c5-4983-885f-db3be3a5c0d8` |

Both received events had `mail.sendingAccountId=538308268352`, raw SES JSON,
matching outbound message IDs, and `mail.tags["ses:configuration-set"]` containing
`my-first-configuration-set`. SES event timestamps were respectively
`2026-10-03T00:34:42.732Z` and `2026-10-03T00:34:57.307Z` (October 2 in Toronto).
Messages were received for verification with 30-second visibility; none were
deleted or purged. Final queue readback reported three visible messages, zero
in flight, retention `1209600` seconds, and SQS-managed encryption enabled.

Post-cutover readback confirmed domain `FeedbackForwardingStatus=false`, enabled
BOUNCE/COMPLAINT publishing to the expected topic, verified identity and unchanged
successful DKIM tokens, unchanged existing suppression preferences, and intact
Microsoft 365 MX/SPF and authentication DNS. Simulator feedback capture does not
establish real-inbox delivery or authentication-header results.

## Configuration-set migration

The authorized migration on October 2, 2026 replaced `my-first-configuration-set`
with `psg-transactional`. The first reviewed apply added the new set/destination
and changed three resources: SNS policy temporarily allowed both set ARNs,
the domain default switched only after the new destination existed, and forwarding
was temporarily restored for verification. No resources were deleted in this stage.

Both simulator requests omitted `ConfigurationSetName`, confirming default
inheritance for the selected application senders:

| Event | Sender | SES message ID | SQS message ID |
| --- | --- | --- | --- |
| Bounce | `no-reply@preyrasolutions.com` | `010d01a0ff3f56f7-e5857593-6d65-4381-9538-b153edb8c512-000000` | `dad9e4c2-6672-4fbc-a88b-e47e4cd8555b` |
| Complaint | `securetransfer@preyrasolutions.com` | `010d01a0ff3f58fc-f645fa07-cf38-4299-ab6b-c0abaa7ddba7-000000` | `c56cb9ce-860f-4efd-a946-8c2dbb082ac5` |

The raw events carried `mail.tags["ses:configuration-set"]=["psg-transactional"]`.
Their timestamps were `2026-10-03T00:52:16.756Z` and
`2026-10-03T00:52:17.482Z` (20:52 EDT October 2). Diagnostic receives used
60-second visibility; no messages were deleted or purged. An additional service
validation control message was observed during destination creation.

Regional identity inventory showed no other explicit default using the old set.
The inspected ST:TNG code/infra had no explicit configuration-set override.
After verification, the second reviewed apply changed two resources (SNS policy
restricted to the new ARN and forwarding disabled again) and destroyed only the
old set and its event destination. The SNS topic, SQS queue/subscription, identity,
DKIM, DNS and suppression settings were preserved. Configuration-set-specific
metrics now use the new name; historical evidence above retains the old name.
Final AWS MCP readback confirmed only `psg-transactional` exists, the domain
default references it, forwarding is disabled, DKIM remains `SUCCESS` with the
same tokens, and the existing encrypted queue retains its 14-day contract.
`tofu fmt -recursive`, `tofu validate` and `git diff --check` passed. The final
full refreshed OpenTofu plan reported **No changes**.
ST:TNG must use `psg-transactional` for any explicit configuration-set selection.

## Custom MAIL FROM authentication improvement

Custom MAIL FROM was deliberately deferred during the initial feedback-capture
work, then separately authorized on October 2, 2026. `ses.tf` adds:

- `aws_sesv2_email_identity_mail_from_attributes.shared`: envelope-sender domain
  `bounce.preyrasolutions.com`, with `USE_DEFAULT_VALUE` fallback.
- `aws_route53_record.ses_mail_from_mx`: MX
  `10 feedback-smtp.ca-central-1.amazonses.com.`, TTL 300.
- `aws_route53_record.ses_mail_from_spf`: TXT
  `v=spf1 include:amazonses.com ~all`, TTL 300.

Both DNS records are on `bounce.preyrasolutions.com` in existing public zone
`Z2NR9N1YFPSN3U`. The SES resource depends on the DNS records. The reviewed plan
contains **3 additions, 0 updates, 0 destroys**. Formatting and validation passed.
This is optional for sending and feedback capture: it adds relaxed SPF alignment
with the visible From domain alongside DKIM. If SES cannot verify the required MX,
it falls back to its default MAIL FROM domain rather than rejecting sends; SPF
alignment with `preyrasolutions.com` is then lost during fallback.

Root Microsoft 365 MX/SPF, domain identity, successful DKIM settings,
`psg-transactional`, and SNS/SQS feedback capture are preserved. No application
change or new credential is required. This is the SMTP envelope sender/Return-Path,
not the visible From or human Reply-To, and not a mailbox for human feedback.

The authorized apply completed with **3 added, 0 changed, 0 destroyed**.
AWS MCP readback confirmed `MailFromDomainStatus=SUCCESS`; authoritative DNS
queries returned both intended records. Root Microsoft 365 MX/SPF were compared
with pre-apply values and unchanged, as were DKIM tokens/signing, configuration
set selection and disabled feedback forwarding. The full refreshed final plan
reported **No changes**. No test email was sent for this change. A separately
authorized real-inbox header check can confirm Return-Path/SPF alignment when
testing application mail; the SES `SUCCESS` status confirms DNS verification.

## Follow-up: ST:TNG feedback consumer

Track this in `TODO.md`: implement a narrow SES feedback ingestion adapter in
ST:TNG, using the existing Watermill/PostgreSQL event-processing direction.
Treat SQS as the external feedback buffer, not a replacement internal broker.
Define the provider-to-internal event mapping, stable deduplication identity,
durable commit/ack boundary, and scoped consumer permissions before implementation.
The current SES adapter discards the `SendEmail` result; provider message-ID
correlation with application sends is a separate future decision.

Consumer implementation and its application behavior require a separate task.
Do not include retry, suppression, UI, notification-state handling or payload
logging as implicit work in this infrastructure change.
