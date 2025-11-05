resource "aws_sqs_queue" "soar_dlq" {
  name = "${local.name_prefix}-soar-dlq"
}

resource "aws_sqs_queue" "soar_events" {
  name                       = "${local.name_prefix}-soar-events"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.soar_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_iam_policy" "lambda_sqs_policy" {
  name        = "${local.name_prefix}-lambda-sqs-policy"
  description = "Allow Lambda to interact with SOAR SQS and DLQ"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect : "Allow",
        Action : [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ],
        Resource : [
          aws_sqs_queue.soar_events.arn,
          aws_sqs_queue.soar_dlq.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_sqs_to_log_to_s3" {
  role       = local.log_to_s3_role_name
  policy_arn = aws_iam_policy.lambda_sqs_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_sqs_to_enqueue" {
  role       = local.enqueue_to_sqs_role_name
  policy_arn = aws_iam_policy.lambda_sqs_policy.arn
}

resource "aws_lambda_event_source_mapping" "soar_sqs_trigger" {
  event_source_arn = aws_sqs_queue.soar_events.arn
  function_name    = data.aws_lambda_function.log_to_s3.arn
  batch_size       = 1
  enabled          = true
}
