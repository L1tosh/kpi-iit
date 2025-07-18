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

data "aws_security_group" "app_sg" {
  filter {
    name   = "group-name"
    values = ["app_security_group_new"] 
  }
}

resource "aws_instance" "app" {
  ami             = "ami-0c1ac8a41498c1a9c"
  instance_type   = "t3.micro"
  key_name        = "keyforlab4"
  security_groups = [data.aws_security_group.app_sg.name]

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install -y docker.io
    systemctl start docker
    systemctl enable docker
    sudo docker login -u ${local.docker_creds.DOCKER_USERNAME} -p ${local.docker_creds.DOCKER_HUB_TOKEN}
    sudo docker run -d -p 80:80 --name my-web-app l1tosh/my-web-app:latest
    sudo docker run -d --name watchtower -v /var/run/docker.sock:/var/run/docker.sock --restart=unless-stopped containrrr/watchtower --interval 60
  EOF

  tags = {
    Name = "my-app-instance"
  }

  depends_on = [data.aws_secretsmanager_secret_version.creds]
}