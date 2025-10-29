resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.name_prefix}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name_prefix}-igw" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[0]
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "${local.name_prefix}-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[1]
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true
  tags                    = { Name = "${local.name_prefix}-public-b" }
}

resource "aws_subnet" "private_app_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_app_cidrs[0]
  availability_zone = "eu-central-1a"
  tags              = { Name = "${local.name_prefix}-private-app-a" }
}

resource "aws_subnet" "private_app_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_app_cidrs[1]
  availability_zone = "eu-central-1b"
  tags              = { Name = "${local.name_prefix}-private-app-b" }
}

resource "aws_subnet" "private_data_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_data_cidrs[0]
  availability_zone = "eu-central-1a"
  tags              = { Name = "${local.name_prefix}-private-data-a" }
}

resource "aws_subnet" "private_data_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_data_cidrs[1]
  availability_zone = "eu-central-1b"
  tags              = { Name = "${local.name_prefix}-private-data-b" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${local.name_prefix}-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  tags          = { Name = "${local.name_prefix}-nat" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "${local.name_prefix}-public-rt" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = { Name = "${local.name_prefix}-private-rt" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_app_a" {
  subnet_id      = aws_subnet.private_app_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_app_b" {
  subnet_id      = aws_subnet.private_app_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_data_a" {
  subnet_id      = aws_subnet.private_data_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_data_b" {
  subnet_id      = aws_subnet.private_data_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "alb_sg" {
  name   = "${local.name_prefix}-alb-sg"
  vpc_id = aws_vpc.this.id

  ingress {
    description = "HTTP verkeer (tijdelijk publiek voor test)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-alb-sg" }
}

resource "aws_security_group" "app_sg" {
  name   = "${local.name_prefix}-app-sg"
  vpc_id = aws_vpc.this.id

  ingress {
    description     = "Verkeer van ALB naar ECS-tasks"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-app-sg" }
}

resource "aws_lb" "app" {
  name                       = "${local.name_prefix}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb_sg.id]
  subnets                    = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  enable_deletion_protection = false
  tags                       = { Name = "${local.name_prefix}-alb" }
}

resource "aws_lb_target_group" "app" {
  name        = "${local.name_prefix}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }

  tags = { Name = "${local.name_prefix}-tg" }
}

# resource "aws_lb_target_group" "shuffle" {
#   name        = "${local.name_prefix}-shuffle-tg"
#   port        = 3000
#   protocol    = "HTTP"
#   vpc_id      = aws_vpc.this.id
#   target_type = "ip"

#   health_check {
#     enabled             = true
#     path                = "/login"
#     protocol            = "HTTP"
#     matcher             = "200-302"
#     interval            = 30
#     timeout             = 5
#     healthy_threshold   = 2
#     unhealthy_threshold = 5
#   }

#   tags = { Name = "${local.name_prefix}-shuffle-tg" }
# }

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# resource "aws_lb_listener_rule" "shuffle" {
#   listener_arn = aws_lb_listener.http.arn
#   priority     = 20

#   action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.shuffle.arn
#   }

#   condition {
#     path_pattern {
#       values = ["/shuffle*", "/login*"]
#     }
#   }
# }

