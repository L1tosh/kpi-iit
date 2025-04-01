terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.11.3"
}

provider "aws" {
  region = "eu-north-1"
}

data "aws_secretsmanager_secret_version" "creds" {
  secret_id  = "docker-hub-creds-v2"
}

locals {
  docker_creds = jsondecode(data.aws_secretsmanager_secret_version.creds.secret_string)
}

resource "aws_security_group" "app_sg" {
  name        = "app_security_group"
  description = "Allow inbound traffic for the app"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

resource "aws_instance" "app" {
  ami             = "ami-03f71e078efdce2c9"
  instance_type   = "t3.micro"
  key_name        = "keyforlab4"
  security_groups = [aws_security_group.app_sg.name]

  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install -y docker.io
    systemctl start docker
    systemctl enable docker
    docker login -u ${local.docker_creds.DOCKER_USERNAME} -p ${local.docker_creds.DOCKER_HUB_TOKEN}
    docker run -d -p 80:80 --name my-web-app l1tosh/my-web-app:latest
    docker run -d --name watchtower -v /var/run/docker.sock:/var/run/docker.sock --restart=unless-stopped containrrr/watchtower --interval 60
  EOF

  tags = {
    Name = "my-app-instance"
  }

  depends_on = [data.aws_secretsmanager_secret_version.creds]
}
