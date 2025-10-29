# resource "aws_cloudwatch_log_group" "shuffle" {
#   name              = "/ecs/shuffle-soar"
#   retention_in_days = 14
# }

# data "aws_iam_policy_document" "shuffle_assume" {
#   statement {
#     actions = ["sts:AssumeRole"]
#     principals {
#       type        = "Service"
#       identifiers = ["ecs-tasks.amazonaws.com"]
#     }
#   }
# }

# resource "aws_iam_role" "shuffle_exec" {
#   name               = "${local.name_prefix}-shuffle-exec"
#   assume_role_policy = data.aws_iam_policy_document.shuffle_assume.json
# }

# resource "aws_iam_role_policy_attachment" "shuffle_exec_attach" {
#   role       = aws_iam_role.shuffle_exec.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
# }

# resource "aws_iam_role_policy" "shuffle_secret_access" {
#   name = "${local.name_prefix}-shuffle-secret-access"
#   role = aws_iam_role.shuffle_exec.id
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect   = "Allow",
#       Action   = [
#         "secretsmanager:GetSecretValue",
#         "ecr:GetAuthorizationToken",
#         "logs:CreateLogStream",
#         "logs:PutLogEvents"
#       ],
#       Resource = "*"
#     }]
#   })
# }

# resource "aws_service_discovery_private_dns_namespace" "shuffle_ns" {
#   name        = "shuffle.local"
#   vpc         = aws_vpc.this.id
#   description = "Private namespace for Shuffle ECS services (automatisch via IaC)"
# }

# resource "aws_service_discovery_service" "shuffle_service" {
#   name         = "shuffle"
#   namespace_id = aws_service_discovery_private_dns_namespace.shuffle_ns.id

#   dns_config {
#     namespace_id = aws_service_discovery_private_dns_namespace.shuffle_ns.id
#     dns_records {
#       type = "A"
#       ttl  = 10
#     }
#     routing_policy = "MULTIVALUE"
#   }
# }

# resource "aws_service_discovery_instance" "shuffle_instance" {
#   service_id  = aws_service_discovery_service.shuffle_service.id
#   instance_id = "shuffle-instance"

#   attributes = {
#     AWS_INSTANCE_IPV4 = "10.10.4.42"
#     AWS_INSTANCE_PORT = "9200"
#   }
# }

# resource "aws_ecs_task_definition" "shuffle" {
#   family                   = "${local.name_prefix}-shuffle"
#   requires_compatibilities = ["FARGATE"]
#   network_mode             = "awsvpc"
#   cpu                      = 4096
#   memory                   = 8192
#   execution_role_arn       = aws_iam_role.shuffle_exec.arn

#   container_definitions = jsonencode([
#     {
#       name         = "opensearch",
#       image        = "public.ecr.aws/opensearchproject/opensearch:2.14.0",
#       essential    = true,
#       portMappings = [{ containerPort = 9200, protocol = "tcp" }],
#       environment = [
#         { name = "discovery.type", value = "single-node" },
#         { name = "DISABLE_SECURITY_PLUGIN", value = "true" },
#         { name = "OPENSEARCH_JAVA_OPTS", value = "-Xms512m -Xmx512m" }
#       ],
#       logConfiguration = {
#         logDriver = "awslogs",
#         options = {
#           "awslogs-group"         = aws_cloudwatch_log_group.shuffle.name,
#           "awslogs-region"        = var.aws_region,
#           "awslogs-stream-prefix" = "opensearch"
#         }
#       }
#     },
#     {
#       name         = "backend",
#       image        = "ghcr.io/frikky/shuffle-backend:1.1.0",
#       essential    = true,
#       dependsOn    = [{ containerName = "opensearch", condition = "START" }],
#       portMappings = [{ containerPort = 5001, protocol = "tcp" }],
#       repository_credentials = {
#         credentialsParameter = "arn:aws:secretsmanager:eu-central-1:760981412376:secret:github/ghcr-creds"
#       },
#       environment = [
#         { name = "SHUFFLE_OPENSEARCH_URL", value = "http://shuffle.shuffle.local:9200" },
#         { name = "SHUFFLE_DEFAULT_USERNAME", value = "admin" },
#         { name = "SHUFFLE_DEFAULT_PASSWORD", value = "changeme" },
#         { name = "SHUFFLE_SKIP_DOCKER",     value = "true" }
#       ],
#       logConfiguration = {
#         logDriver = "awslogs",
#         options = {
#           "awslogs-group"         = aws_cloudwatch_log_group.shuffle.name,
#           "awslogs-region"        = var.aws_region,
#           "awslogs-stream-prefix" = "backend"
#         }
#       }
#     },
#     {
#       name         = "frontend",
#       image        = "ghcr.io/frikky/shuffle-frontend:1.1.0",
#       essential    = true,
#       dependsOn    = [{ containerName = "backend", condition = "START" }],
#       portMappings = [{ containerPort = 3000, protocol = "tcp" }],
#       repository_credentials = {
#         credentialsParameter = "arn:aws:secretsmanager:eu-central-1:760981412376:secret:github/ghcr-creds"
#       },
#       environment = [
#         { name = "SHUFFLE_BACKEND_HOST",   value = "http://shuffle.shuffle.local:5001" },
#         { name = "SHUFFLE_OPENSEARCH_URL", value = "http://shuffle.shuffle.local:9200" },
#         { name = "SHUFFLE_DEFAULT_USERNAME", value = "admin" },
#         { name = "SHUFFLE_DEFAULT_PASSWORD", value = "changeme" }
#       ],
#       logConfiguration = {
#         logDriver = "awslogs",
#         options = {
#           "awslogs-group"         = aws_cloudwatch_log_group.shuffle.name,
#           "awslogs-region"        = var.aws_region,
#           "awslogs-stream-prefix" = "frontend"
#         }
#       }
#     },
#     {
#       name         = "worker",
#       image        = "ghcr.io/frikky/shuffle-worker:1.2.0",
#       essential    = false,
#       dependsOn    = [{ containerName = "backend", condition = "START" }],
#       repository_credentials = {
#         credentialsParameter = "arn:aws:secretsmanager:eu-central-1:760981412376:secret:github/ghcr-creds"
#       },
#       environment = [
#         { name = "SHUFFLE_BACKEND_HOST",   value = "http://shuffle.shuffle.local:5001" },
#         { name = "SHUFFLE_OPENSEARCH_URL", value = "http://shuffle.shuffle.local:9200" }
#       ],
#       logConfiguration = {
#         logDriver = "awslogs",
#         options = {
#           "awslogs-group"         = aws_cloudwatch_log_group.shuffle.name,
#           "awslogs-region"        = var.aws_region,
#           "awslogs-stream-prefix" = "worker"
#         }
#       }
#     }
#   ])
# }

# resource "aws_lb_target_group" "shuffle_tg" {
#   name        = "${local.name_prefix}-tg-shuffle"
#   port        = 3000
#   protocol    = "HTTP"
#   vpc_id      = aws_vpc.this.id
#   target_type = "ip"

#   health_check {
#     path                = "/login"
#     protocol            = "HTTP"
#     matcher             = "200-302"
#     interval            = 30
#     timeout             = 5
#     healthy_threshold   = 2
#     unhealthy_threshold = 5
#   }
# }

# resource "aws_ecs_service" "shuffle" {
#   name            = "${local.name_prefix}-shuffle"
#   cluster         = aws_ecs_cluster.this.id
#   task_definition = aws_ecs_task_definition.shuffle.arn
#   desired_count   = 1
#   launch_type     = "FARGATE"

#   deployment_minimum_healthy_percent = 50
#   deployment_maximum_percent         = 200

#   network_configuration {
#     subnets          = [aws_subnet.private_app_a.id, aws_subnet.private_app_b.id]
#     security_groups  = [aws_security_group.app_sg.id]
#     assign_public_ip = false
#   }

#   load_balancer {
#     target_group_arn = aws_lb_target_group.shuffle_tg.arn
#     container_name   = "frontend"
#     container_port   = 3000
#   }

#   depends_on = [aws_lb_listener_rule.shuffle_rule]
# }

# resource "aws_lb_listener_rule" "shuffle_rule" {
#   listener_arn = aws_lb_listener.http.arn
#   priority     = 33

#   action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.shuffle_tg.arn
#   }

#   condition {
#     path_pattern {
#       values = ["/shuffle*", "/login*"]
#     }
#   }
# }

# output "shuffle_url" {
#   description = "Publieke URL van Shuffle SOAR via ALB"
#   value       = "http://${aws_lb.app.dns_name}/shuffle/login"
# }
