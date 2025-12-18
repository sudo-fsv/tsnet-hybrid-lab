provider "aws" {
  region = var.aws_region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# VPC for GitHub Actions runner: single public subnet (192.168.253.0/24)
resource "aws_vpc" "runner_vpc" {
  cidr_block           = "192.168.253.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "gh-runner-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.runner_vpc.id
  cidr_block              = "192.168.253.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "gh-runner-public-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.runner_vpc.id

  tags = {
    Name = "gh-runner-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.runner_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "gh-runner-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "ssh" {
  name        = "gh-runner-ssh"
  description = "Allow SSH to the GitHub Actions self-hosted runner"
  vpc_id      = aws_vpc.runner_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.enable_ssh_access ? ["0.0.0.0/0"] : []
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# CI/CD LAB pipeline will load user credentials with required permissions. 
# This logic can be improved to AssumeRole via attached instance profile instead.
resource "aws_instance" "runner" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  vpc_security_group_ids = [aws_security_group.ssh.id]
  subnet_id              = aws_subnet.public.id
  associate_public_ip_address = true
  key_name               = var.key_name != "" ? var.key_name : null

  user_data = templatefile("${path.module}/user_data.tpl", {
    github_owner        = var.github_owner
    github_repo         = var.github_repo
    github_runner_token = var.github_runner_token
    github_token        = var.github_token
    runner_name         = var.runner_name
    runner_labels       = join(",", var.runner_labels)
  })

  tags = {
    Name = "github-actions-self-hosted-runner"
  }
}