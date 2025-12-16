provider "aws" {
  region = var.aws_region
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_security_group" "ssh" {
  name        = "gh-runner-ssh"
  description = "Allow SSH to the GitHub Actions self-hosted runner"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# NOTE: The IAM role and policy below grant broad EC2 permissions (ec2:*) and
# are overly permissive. This is intended for lab or disposable environments
# where convenience is preferred over least-privilege. Do NOT use in production.

# IAM role assumed by the EC2 instance so the runner can manage EC2/VPC resources
resource "aws_iam_role" "runner_role" {
  name               = "gh-actions-runner-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Inline policy granting EC2 (including VPC) full access. Overly permissive.
resource "aws_iam_role_policy" "runner_role_policy" {
  name = "gh-runner-ec2-vpc-full"
  role = aws_iam_role.runner_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "ec2:*"
        Resource = "*"
      }
    ]
  })
}

# Instance profile to attach to the EC2 instance
resource "aws_iam_instance_profile" "runner_profile" {
  name = "gh-actions-runner-profile"
  role = aws_iam_role.runner_role.name
}

resource "aws_instance" "runner" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.ssh.id]
  key_name               = var.key_name != "" ? var.key_name : null

  user_data = templatefile("${path.module}/user_data.tpl", {
    github_owner        = var.github_owner
    github_repo         = var.github_repo
    github_runner_token = var.github_runner_token
    runner_name         = var.runner_name
    runner_labels       = join(",", var.runner_labels)
  })

  iam_instance_profile = aws_iam_instance_profile.runner_profile.name

  tags = {
    Name = "github-actions-self-hosted-runner"
  }
}

output "instance_id" {
  value = aws_instance.runner.id
}

output "public_ip" {
  value = aws_instance.runner.public_ip
}
