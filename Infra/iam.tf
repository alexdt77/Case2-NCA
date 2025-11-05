data "aws_iam_policy_document" "rds_proxy_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_proxy_role" {
  name               = "${local.name_prefix}-rds-proxy-role"
  assume_role_policy = data.aws_iam_policy_document.rds_proxy_assume.json
}

resource "aws_iam_role_policy_attachment" "rds_proxy_access" {
  role       = aws_iam_role.rds_proxy_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${local.name_prefix}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_s3_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_policy" "lambda_sqs_receive" {
  name        = "${local.name_prefix}-lambda-sqs-receive"
  description = "Allow Lambda to read and delete messages from SOAR SQS queues"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect : "Allow",
        Action : [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource : [
          aws_sqs_queue.soar_events.arn,
          aws_sqs_queue.soar_dlq.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_lambda_sqs_receive_to_log_to_s3" {
  role       = local.log_to_s3_role_name
  policy_arn = aws_iam_policy.lambda_sqs_receive.arn
}

data "aws_iam_policy_document" "wg_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "wg_ssm_role" {
  name               = "${local.name_prefix}-wg-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.wg_assume.json
}

resource "aws_iam_role_policy_attachment" "wg_ssm_core" {
  role       = aws_iam_role.wg_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "wg_profile" {
  name = "${local.name_prefix}-wg-profile"
  role = aws_iam_role.wg_ssm_role.name
}


