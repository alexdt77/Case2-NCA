data "aws_availability_zones" "this" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.this.names, 0, 2)
}

resource "aws_dynamodb_table" "soar_events" {
  name         = "${local.name_prefix}-soar-events"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"

  attribute {
    name = "event_id"
    type = "S"
  }

  tags = {
    Name        = "${local.name_prefix}-soar-events"
    Environment = var.env
    Owner       = var.owner
  }
}

resource "aws_dynamodb_table" "soar_actions" {
  name         = "${local.name_prefix}-soar-actions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "action_id"

  attribute {
    name = "action_id"
    type = "S"
  }

  tags = {
    Name        = "${local.name_prefix}-soar-actions"
    Environment = var.env
    Owner       = var.owner
  }
}

data "aws_iam_policy_document" "soar_dynamo_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "soar_dynamo_role" {
  name               = "${local.name_prefix}-soar-dynamo-role"
  assume_role_policy = data.aws_iam_policy_document.soar_dynamo_assume.json
}

resource "aws_iam_role_policy" "soar_dynamo_policy" {
  name = "${local.name_prefix}-soar-dynamo-policy"
  role = aws_iam_role.soar_dynamo_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.soar_events.arn,
          aws_dynamodb_table.soar_actions.arn
        ]
      }
    ]
  })
}

output "soar_events_table_name" {
  description = "Naam van de DynamoDB-tabel met SOAR events"
  value       = aws_dynamodb_table.soar_events.name
}

output "soar_actions_table_name" {
  description = "Naam van de DynamoDB-tabel met uitgevoerde acties"
  value       = aws_dynamodb_table.soar_actions.name
}

output "soar_dynamo_role_arn" {
  description = "IAM Role ARN die ECS/Lambda mag gebruiken voor DynamoDB toegang"
  value       = aws_iam_role.soar_dynamo_role.arn
}
