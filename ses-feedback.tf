# Retain SES feedback without application processing or operator subscriptions.
variable "ses_feedback_capture_verified" {
  description = "Set true only after authorized end-to-end bounce/complaint capture and application configuration-set coverage are verified. Disables domain email feedback forwarding."
  type        = bool
  # Authorized Bounce and Complaint simulator events reached this queue on
  # 2026-10-02 with the psg-transactional identity default after migration.
  # See docs/shared-ses.md for the message IDs and cutover evidence.
  # Set false to restore forwarding during a reviewed capture-path repair.
  default = true
}

resource "aws_sns_topic" "ses_feedback" {
  name = "psg-ses-feedback"

  tags = {
    Name    = "psg-ses-feedback"
    Owner   = "PSG"
    Purpose = "Shared SES bounce and complaint capture"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_sns_topic_policy" "ses_feedback" {
  arn = aws_sns_topic.ses_feedback.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowSharedSESFeedback"
      Effect    = "Allow"
      Principal = { Service = "ses.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.ses_feedback.arn
      Condition = {
        StringEquals = { "AWS:SourceAccount" = var.aws_account_id }
        ArnEquals    = { "AWS:SourceArn" = aws_sesv2_configuration_set.transactional.arn }
      }
    }]
  })
}

resource "aws_sqs_queue" "ses_feedback" {
  name                      = "psg-ses-feedback"
  message_retention_seconds = 1209600 # 14 days: SQS maximum, not an archive.
  receive_wait_time_seconds = 20
  sqs_managed_sse_enabled   = true

  tags = {
    Name    = "psg-ses-feedback"
    Owner   = "PSG"
    Purpose = "Retain SES bounce and complaint events pending a consumer"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_sqs_queue_policy" "ses_feedback" {
  queue_url = aws_sqs_queue.ses_feedback.url
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowSharedSESFeedbackTopic"
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.ses_feedback.arn
      Condition = {
        StringEquals = { "aws:SourceAccount" = var.aws_account_id }
        ArnEquals    = { "aws:SourceArn" = aws_sns_topic.ses_feedback.arn }
      }
    }]
  })
}

resource "aws_sns_topic_subscription" "ses_feedback" {
  topic_arn            = aws_sns_topic.ses_feedback.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.ses_feedback.arn
  raw_message_delivery = true

  depends_on = [aws_sqs_queue_policy.ses_feedback]
}

resource "aws_sesv2_configuration_set_event_destination" "transactional_feedback" {
  configuration_set_name = aws_sesv2_configuration_set.transactional.configuration_set_name
  event_destination_name = "psg-bounce-complaint"

  event_destination {
    enabled              = true
    matching_event_types = ["BOUNCE", "COMPLAINT"]
    sns_destination {
      topic_arn = aws_sns_topic.ses_feedback.arn
    }
  }

  # Establish the complete capture path before enabling SES event publishing.
  depends_on = [aws_sns_topic_policy.ses_feedback, aws_sns_topic_subscription.ses_feedback]
}

output "ses_feedback_topic_arn" {
  description = "SNS topic receiving only SES bounce and complaint events."
  value       = aws_sns_topic.ses_feedback.arn
}

output "ses_feedback_queue_arn" {
  description = "Shared feedback queue ARN; future consumer permission belongs to its owning application."
  value       = aws_sqs_queue.ses_feedback.arn
}

output "ses_feedback_queue_url" {
  description = "Queue retaining raw SES bounce/complaint JSON for up to 14 days."
  value       = aws_sqs_queue.ses_feedback.url
}
