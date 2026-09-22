resource "aws_ssm_document" "session_manager_preferences" {
  name            = "SSM-SessionManagerRunShell"
  document_type   = "Session"
  document_format = "JSON"

  # SSM compares document content byte-for-byte. Keep this in the canonical
  # serialization returned by AWS to avoid perpetual whitespace-only updates.
  content = trimspace(<<-JSON
    {"schemaVersion":"1.0","description":"Document to hold regional settings for Session Manager","sessionType":"Standard_Stream","inputs":{"s3BucketName":"","s3KeyPrefix":"","s3EncryptionEnabled":true,"cloudWatchLogGroupName":"","cloudWatchEncryptionEnabled":true,"idleSessionTimeout":"60","maxSessionDuration":"","cloudWatchStreamingEnabled":true,"kmsKeyId":"","runAsEnabled":false,"runAsDefaultUser":"","shellProfile":{"windows":"","linux":"cd \"$HOME\"\nexec /bin/bash -l"}}}
  JSON
  )

  lifecycle {
    prevent_destroy = true
  }
}
