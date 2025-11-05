data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_security_group" "wg_gw_sg" {
  name   = "${local.name_prefix}-wg-gw-sg"
  vpc_id = aws_vpc.this.id

  ingress {
    protocol    = "udp"
    from_port   = var.wg_port
    to_port     = var.wg_port
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-wg-sg"
  }
}

resource "aws_instance" "wg_gw" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.wg_gw_sg.id]
  associate_public_ip_address = true
  source_dest_check           = false
  iam_instance_profile        = aws_iam_instance_profile.wg_profile.name

    user_data = <<-CLOUDINIT
    #!/bin/bash
    set -e
    apt-get update -y

    apt-get install -y amazon-ssm-agent
    systemctl enable --now amazon-ssm-agent

    apt-get install -y wireguard

    # Generate server keypair
    umask 077
    wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
    SERVER_PRIV=$(cat /etc/wireguard/server_private.key)

    # Write WireGuard config
    cat >/etc/wireguard/wg0.conf <<EOF
    [Interface]
    Address = 10.250.0.1/30
    ListenPort = ${var.wg_port}
    PrivateKey = $SERVER_PRIV

    PostUp = sysctl -w net.ipv4.ip_forward=1
    # NAT example:
    # PostUp = iptables -t nat -A POSTROUTING -s ${var.onprem_cidr} -o eth0 -j MASQUERADE
    # PostDown = iptables -t nat -D POSTROUTING -s ${var.onprem_cidr} -o eth0 -j MASQUERADE

    [Peer]
    PublicKey = 2nQ4qgfQunLhKCW986L50ZfDnQVMr+JdCteMvrnlYVo=
    AllowedIPs = 172.16.2.0/24,10.250.0.2/32
    PersistentKeepalive = 25
    EOF

    systemctl enable wg-quick@wg0
  CLOUDINIT

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "${local.name_prefix}-wg-gw"
  }
}

resource "aws_eip" "wg_gw" {
  instance = aws_instance.wg_gw.id
  domain   = "vpc"

  tags = {
    Name = "${local.name_prefix}-wg-eip"
  }
}

data "aws_network_interface" "wg_gw_eni" {
  filter {
    name   = "attachment.instance-id"
    values = [aws_instance.wg_gw.id]
  }
}

resource "aws_route" "private_to_onprem" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = var.onprem_cidr
  network_interface_id   = data.aws_network_interface.wg_gw_eni.id
}

