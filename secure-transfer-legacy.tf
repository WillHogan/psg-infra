resource "aws_s3_bucket" "secure_transfer_legacy" {
  bucket        = "psg-secure-transfer-legacy-${var.aws_account_id}"
  force_destroy = false

  tags = {
    Name    = "psg-secure-transfer-legacy"
    Owner   = "PSG"
    Purpose = "Read-only legacy Secure Transfer file access"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "secure_transfer_legacy" {
  bucket = aws_s3_bucket.secure_transfer_legacy.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secure_transfer_legacy" {
  bucket = aws_s3_bucket.secure_transfer_legacy.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "secure_transfer_legacy" {
  bucket = aws_s3_bucket.secure_transfer_legacy.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "secure_transfer_legacy" {
  bucket = aws_s3_bucket.secure_transfer_legacy.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "secure_transfer_legacy" {
  bucket = aws_s3_bucket.secure_transfer_legacy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.secure_transfer_legacy.arn,
        "${aws_s3_bucket.secure_transfer_legacy.arn}/*"
      ]
      Condition = {
        Bool = {
          "aws:SecureTransport" = "false"
        }
      }
    }]
  })
}

resource "aws_iam_role" "secure_transfer_legacy_sync" {
  name        = "psg-secure-transfer-legacy-sync"
  description = "Uploads the legacy Secure Transfer filesystem mirror to S3."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name    = "psg-secure-transfer-legacy-sync"
    Owner   = "PSG"
    Purpose = "Legacy Secure Transfer S3 synchronization"
  }
}

resource "aws_iam_role_policy" "secure_transfer_legacy_sync" {
  name = "sync-legacy-files-to-s3"
  role = aws_iam_role.secure_transfer_legacy_sync.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DiscoverLegacyMirror"
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket", "s3:ListBucketMultipartUploads"]
        Resource = aws_s3_bucket.secure_transfer_legacy.arn
      },
      {
        Sid      = "UploadLegacyMirror"
        Effect   = "Allow"
        Action   = ["s3:AbortMultipartUpload", "s3:ListMultipartUploadParts", "s3:PutObject"]
        Resource = "${aws_s3_bucket.secure_transfer_legacy.arn}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "secure_transfer_legacy_sync" {
  name = "psg-secure-transfer-legacy-sync"
  role = aws_iam_role.secure_transfer_legacy_sync.name

  tags = {
    Name    = "psg-secure-transfer-legacy-sync"
    Owner   = "PSG"
    Purpose = "Legacy Secure Transfer S3 synchronization"
  }
}

# The legacy host predates this OpenTofu configuration, so manage only the
# temporary access tag needed to select it as a Session Manager shell target.
resource "aws_ec2_tag" "secure_transfer_legacy_ssm_shell_access" {
  resource_id = "i-0219c4b935c853975"
  key         = "SSMShellAccess"
  value       = "true"
}

resource "aws_ssoadmin_permission_set" "secure_transfer_legacy_read_only" {
  instance_arn = local.identity_center_instance_arn

  name             = "PSG-ST-Legacy-ReadOnly"
  description      = "Read-only CLI and browser access to the legacy Secure Transfer file mirror."
  session_duration = "PT8H"
}

resource "aws_ssoadmin_permission_set_inline_policy" "secure_transfer_legacy_read_only" {
  instance_arn       = local.identity_center_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.secure_transfer_legacy_read_only.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DiscoverBucketsInConsole"
        Effect   = "Allow"
        Action   = "s3:ListAllMyBuckets"
        Resource = "*"
      },
      {
        Sid      = "ListLegacyMirror"
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket", "s3:ListBucketVersions"]
        Resource = aws_s3_bucket.secure_transfer_legacy.arn
      },
      {
        Sid      = "ReadLegacyMirror"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "${aws_s3_bucket.secure_transfer_legacy.arn}/*"
      }
    ]
  })
}
