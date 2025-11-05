data "aws_lambda_function" "log_to_s3" {
  function_name = "log_to_s3"
}

data "aws_lambda_function" "fake_firewall_block_ip" {
  function_name = "fake_firewall_block_ip"
}

data "aws_lambda_function" "enqueue_to_sqs" {
  function_name = "send_to_shuffle"
}

resource "aws_lambda_function_url" "enqueue_url" {
  function_name      = data.aws_lambda_function.enqueue_to_sqs.function_name
  authorization_type = "NONE"
}

locals {
  log_to_s3_role_name      = element(split("/", data.aws_lambda_function.log_to_s3.role), length(split("/", data.aws_lambda_function.log_to_s3.role)) - 1)
  enqueue_to_sqs_role_name = element(split("/", data.aws_lambda_function.enqueue_to_sqs.role), length(split("/", data.aws_lambda_function.enqueue_to_sqs.role)) - 1)
}


