resource "aws_s3_bucket" "psg_dataset_outputs" {
  bucket        = "psg-dataset-outputs"
  force_destroy = false

  tags = {
    Name    = "psg-dataset-outputs"
    Owner   = "PSG"
    Purpose = "PSG PPTX dataset outputs"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "psg_dataset_outputs" {
  bucket = aws_s3_bucket.psg_dataset_outputs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "psg_dataset_outputs" {
  bucket = aws_s3_bucket.psg_dataset_outputs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "psg_dataset_outputs" {
  bucket = aws_s3_bucket.psg_dataset_outputs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "psg_dataset_outputs" {
  bucket = aws_s3_bucket.psg_dataset_outputs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "psg_dataset_outputs" {
  bucket = aws_s3_bucket.psg_dataset_outputs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowPsgPptxHostRole"
      Effect    = "Allow"
      Principal = { AWS = aws_iam_role.psg_pptx_host.arn }
      Action    = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.psg_dataset_outputs.arn,
        "${aws_s3_bucket.psg_dataset_outputs.arn}/*"
      ]
    }]
  })
}

resource "aws_ssoadmin_permission_set" "dataset_outputs_access" {
  instance_arn = local.identity_center_instance_arn

  name             = "PSG-Dataset-Outputs-Access"
  description      = "Direct read and write access to the PSG dataset outputs bucket."
  session_duration = "PT8H"
}

resource "aws_ssoadmin_permission_set_inline_policy" "dataset_outputs_access" {
  instance_arn       = local.identity_center_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.dataset_outputs_access.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListDatasetOutputs"
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket", "s3:ListBucketMultipartUploads"]
        Resource = aws_s3_bucket.psg_dataset_outputs.arn
      },
      {
        Sid      = "ReadAndWriteDatasetOutputs"
        Effect   = "Allow"
        Action   = ["s3:AbortMultipartUpload", "s3:GetObject", "s3:ListMultipartUploadParts", "s3:PutObject"]
        Resource = "${aws_s3_bucket.psg_dataset_outputs.arn}/*"
      }
    ]
  })
}

import {
  to = aws_s3_bucket.psg_dataset_outputs
  id = "psg-dataset-outputs"
}

import {
  to = aws_s3_bucket_versioning.psg_dataset_outputs
  id = "psg-dataset-outputs"
}

import {
  to = aws_s3_bucket_server_side_encryption_configuration.psg_dataset_outputs
  id = "psg-dataset-outputs"
}

import {
  to = aws_s3_bucket_ownership_controls.psg_dataset_outputs
  id = "psg-dataset-outputs"
}

import {
  to = aws_s3_bucket_public_access_block.psg_dataset_outputs
  id = "psg-dataset-outputs"
}

import {
  to = aws_s3_bucket_policy.psg_dataset_outputs
  id = "psg-dataset-outputs"
}
