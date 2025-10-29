data "aws_iam_policy_document" "ssm_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitor_role" {
  name               = "${local.name_prefix}-monitor-role"
  assume_role_policy = data.aws_iam_policy_document.ssm_assume.json
}

resource "aws_iam_role_policy_attachment" "monitor_ssm" {
  role       = aws_iam_role.monitor_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "monitor_profile" {
  name = "${local.name_prefix}-monitor-profile"
  role = aws_iam_role.monitor_role.name
}

resource "aws_security_group" "monitor_sg" {
  name   = "${local.name_prefix}-monitor-sg"
  vpc_id = aws_vpc.this.id

  ingress {
    description = "Toegang vanaf private subnets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.private_app_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.name_prefix}-monitor-sg" }
}

resource "aws_instance" "monitor" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private_app_a.id
  vpc_security_group_ids      = [aws_security_group.monitor_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.monitor_profile.name
  associate_public_ip_address = false

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    amazon-linux-extras install docker -y
    systemctl enable docker
    systemctl start docker

    # Prometheus configuratie
    cat <<EOT > /home/ec2-user/prometheus.yml
    global:
      scrape_interval: 15s
    scrape_configs:
      - job_name: 'node'
        static_configs:
          - targets: ['localhost:9100']
    EOT

    # Docker containers starten
    docker run -d --name node_exporter -p 9100:9100 prom/node-exporter
    docker run -d --name prometheus -p 9090:9090 -v /home/ec2-user/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus
    docker run -d --name grafana -p 3000:3000 grafana/grafana
  EOF

  tags = {
    Name = "${local.name_prefix}-monitor"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

output "monitor_instance_id" {
  value = aws_instance.monitor.id
}

output "monitor_ssm_command" {
  value = "aws ssm start-session --target ${aws_instance.monitor.id}"
}
