#!/usr/bin/env bash
set -Eeuo pipefail

readonly DESTINATION_BUCKET="${DESTINATION_BUCKET:-psg-secure-transfer-legacy-538308268352}"
readonly AWS_REGION="${AWS_REGION:-ca-central-1}"
readonly SOURCE_DIRECTORY="${1:-}"
readonly LOCK_FILE="/var/lock/psg-secure-transfer-legacy-sync.lock"

if [[ -z "${SOURCE_DIRECTORY}" ]]; then
  echo "usage: $0 SOURCE_DIRECTORY" >&2
  exit 64
fi

if [[ ! -d "${SOURCE_DIRECTORY}" || ! -r "${SOURCE_DIRECTORY}" ]]; then
  echo "source directory is not a readable directory: ${SOURCE_DIRECTORY}" >&2
  exit 66
fi

command -v aws >/dev/null 2>&1 || {
  echo "aws CLI is required" >&2
  exit 69
}

command -v flock >/dev/null 2>&1 || {
  echo "flock is required" >&2
  exit 69
}

exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
  echo "another legacy-file sync is already running; skipping" >&2
  exit 0
fi

# This is deliberately a one-way, non-deleting mirror. Files removed from the
# legacy host remain available in S3, and changed files create new S3 versions.
printf '%s starting legacy-file sync\n' "$(date --iso-8601=seconds)"
aws s3 sync \
  "${SOURCE_DIRECTORY%/}/" \
  "s3://${DESTINATION_BUCKET}/" \
  --region "${AWS_REGION}" \
  --no-follow-symlinks \
  --only-show-errors
printf '%s completed legacy-file sync\n' "$(date --iso-8601=seconds)"
