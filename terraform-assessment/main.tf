terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ─── AMI Data Source ──────────────────────────────────────────────────────────
# Looks up the latest Amazon Linux 2 AMI automatically so the config stays current.
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ─── VPC ──────────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "techcorp-vpc"
  }
}

# ─── Subnets ──────────────────────────────────────────────────────────────────
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "techcorp-public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "techcorp-public-subnet-2"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.region}a"

  tags = {
    Name = "techcorp-private-subnet-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${var.region}b"

  tags = {
    Name = "techcorp-private-subnet-2"
  }
}

# ─── Internet Gateway ─────────────────────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "techcorp-igw"
  }
}

# ─── Elastic IPs for NAT Gateways ─────────────────────────────────────────────
resource "aws_eip" "nat_1" {
  domain = "vpc"

  tags = {
    Name = "techcorp-nat-eip-1"
  }
}

resource "aws_eip" "nat_2" {
  domain = "vpc"

  tags = {
    Name = "techcorp-nat-eip-2"
  }
}

# ─── NAT Gateways ─────────────────────────────────────────────────────────────
# One per public subnet — private subnets in each AZ egress through their own NAT.
resource "aws_nat_gateway" "nat_1" {
  allocation_id = aws_eip.nat_1.id
  subnet_id     = aws_subnet.public_1.id
  depends_on    = [aws_internet_gateway.main]

  tags = {
    Name = "techcorp-nat-gw-1"
  }
}

resource "aws_nat_gateway" "nat_2" {
  allocation_id = aws_eip.nat_2.id
  subnet_id     = aws_subnet.public_2.id
  depends_on    = [aws_internet_gateway.main]

  tags = {
    Name = "techcorp-nat-gw-2"
  }
}

# ─── Route Tables ─────────────────────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "techcorp-public-rt"
  }
}

# Each private subnet gets its own route table pointing at its local NAT gateway.
resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1.id
  }

  tags = {
    Name = "techcorp-private-rt-1"
  }
}

resource "aws_route_table" "private_2" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_2.id
  }

  tags = {
    Name = "techcorp-private-rt-2"
  }
}

# ─── Route Table Associations ─────────────────────────────────────────────────
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_2.id
}

# ─── Security Groups ──────────────────────────────────────────────────────────

# Bastion SG: SSH from the admin IP only.
resource "aws_security_group" "bastion" {
  name        = "techcorp-bastion-sg"
  description = "Allow SSH inbound from admin IP only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.admin_ip}/32"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "techcorp-bastion-sg"
  }
}

# Web SG: HTTP/HTTPS from anywhere; SSH only from bastion.
resource "aws_security_group" "web" {
  name        = "techcorp-web-sg"
  description = "HTTP/HTTPS from anywhere; SSH from bastion SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "techcorp-web-sg"
  }
}

# Database SG: Postgres from web servers only; SSH from bastion.
resource "aws_security_group" "database" {
  name        = "techcorp-database-sg"
  description = "Postgres from web SG; SSH from bastion SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from web servers"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "techcorp-database-sg"
  }
}

# ALB SG: allow HTTP/HTTPS from anywhere (separate from web-sg so ALB can be created independently).
resource "aws_security_group" "alb" {
  name        = "techcorp-alb-sg"
  description = "Allow HTTP/HTTPS inbound for the ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "techcorp-alb-sg"
  }
}

# ─── Bastion Host ─────────────────────────────────────────────────────────────
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.bastion_instance_type
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = var.key_pair_name

  # Allow password authentication from bastion to web/DB servers.
  user_data = <<-EOF
    #!/bin/bash
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    systemctl restart sshd
  EOF

  tags = {
    Name = "techcorp-bastion"
  }
}

resource "aws_eip" "bastion" {
  instance = aws_instance.bastion.id
  domain   = "vpc"

  tags = {
    Name = "techcorp-bastion-eip"
  }
}

# ─── Web Servers ──────────────────────────────────────────────────────────────
resource "aws_instance" "web_1" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.web_instance_type
  subnet_id              = aws_subnet.private_1.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = var.key_pair_name
  user_data              = file("${path.module}/user_data/web_server_setup.sh")

  tags = {
    Name = "techcorp-web-server-1"
  }
}

resource "aws_instance" "web_2" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.web_instance_type
  subnet_id              = aws_subnet.private_2.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = var.key_pair_name
  user_data              = file("${path.module}/user_data/web_server_setup.sh")

  tags = {
    Name = "techcorp-web-server-2"
  }
}

# ─── Database Server ──────────────────────────────────────────────────────────
resource "aws_instance" "database" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.db_instance_type
  subnet_id              = aws_subnet.private_1.id
  vpc_security_group_ids = [aws_security_group.database.id]
  key_name               = var.key_pair_name
  user_data              = file("${path.module}/user_data/db_server_setup.sh")

  tags = {
    Name = "techcorp-db-server"
  }
}

# ─── Application Load Balancer ────────────────────────────────────────────────
resource "aws_lb" "main" {
  name               = "techcorp-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name = "techcorp-alb"
  }
}

resource "aws_lb_target_group" "web" {
  name     = "techcorp-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "techcorp-web-tg"
  }
}

resource "aws_lb_target_group_attachment" "web_1" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web_2" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web_2.id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
