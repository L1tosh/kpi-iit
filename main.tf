terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "eu-central-1" 
}

data "aws_secretsmanager_secret" "docker_hub_creds" {
  name = "kpi-iit-docker"  
}

data "aws_secretsmanager_secret_version" "docker_hub_creds_version" {
  secret_id = data.aws_secretsmanager_secret.docker_hub_creds.id
}

locals {
  docker_credentials = jsondecode(data.aws_secretsmanager_secret_version.docker_hub_creds_version.secret_string)
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
  ami           = "ami-03f71e078efdce2c9" 
  instance_type = "t3.micro"
  key_name      = ""  
  security_groups = [aws_security_group.app_sg.name]

  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install -y docker.io
    systemctl start docker
    systemctl enable docker
    docker login -u ${local.docker_credentials["DOCKER_USERNAME"]} -p ${local.docker_credentials["DOCKER_HUB_TOKEN"]}
    docker run -d -p 80:80 --name my-web-app l1tosh/my-web-app:latest
    docker run -d --name watchtower -v /var/run/docker.sock:/var/run/docker.sock --restart=unless-stopped containrrr/watchtower --interval 60
  EOF

  tags = {
    Name = "my-app-instance"
  }
}
