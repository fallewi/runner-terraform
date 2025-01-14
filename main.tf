provider "aws" {
  region = "eu-west-1"  # Remplacez par la région de votre choix
}

# Variables
variable "gitlab_runner_token" {
  description = "Le token d'enregistrement du GitLab Runner"
  type        = string
  default = "glpat-VjWLycAni-f8RryCaVSs"
}

data "aws_vpc" "default" {
  default = true
}

variable "instance_type" {
  description = "Type d'instance EC2"
  default     = "t2.micro"
}

variable "ami_id" {
  description = "ID de l'AMI (Amazon Machine Image) pour l'instance EC2"
  default     = "ami-0c55b159cbfafe1f0"  # Remplacez par une AMI appropriée pour votre région
}

variable "key_name" {
  description = "Nom de la clé SSH pour accéder à l'instance EC2"
  type        = string
  default = "toto"
}

# Création d'une clé SSH (si vous n'en avez pas déjà une)
#resource "aws_key_pair" "gitlab_runner" {
  #key_name   = var.key_name
  #public_key = file("~/.ssh/id_rsa.pub")  # Assurez-vous que cette clé existe
#}

# Création d'un groupe de sécurité pour autoriser l'accès SSH et HTTP
resource "aws_security_group" "gitlab_runner_sg" {
  name        = "gitlab-runner-sg"
  description = "Groupe de sécurité pour GitLab Runner"
  vpc_id      = data.aws_vpc.default.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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
}

# Création de l'instance EC2
resource "aws_instance" "gitlab_runner" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  security_groups = [aws_security_group.gitlab_runner_sg.name]
  user_data = <<-EOF
              #!/bin/bash
              # Mettre à jour le système
              sudo apt-get update -y && sudo apt-get upgrade -y

              # Installer Docker
              sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
              sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              sudo apt-get update -y
              sudo apt-get install -y docker-ce
              sudo systemctl enable docker
              sudo systemctl start docker

              # Installer Terraform
              curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
              sudo apt-add-repository "deb https://apt.releases.hashicorp.com stable main"
              sudo apt-get update -y
              sudo apt-get install -y terraform

              # Installer AWS CLI
              sudo apt-get install -y awscli

              # Installer GitLab Runner
              curl -L --output /tmp/gitlab-runner.deb https://gitlab-runner-downloads.s3.amazonaws.com/latest/deb/gitlab-runner_amd64.deb
              sudo dpkg -i /tmp/gitlab-runner.deb

              # Enregistrer le GitLab Runner avec le token d'enregistrement
              sudo gitlab-runner register --non-interactive --url https://gitlab.com/ --registration-token ${var.gitlab_runner_token} --executor shell --description "AWS EC2 Runner" --tag-list "aws,ec2" --run-untagged="true"

              # Démarrer GitLab Runner
              sudo gitlab-runner start
              EOF

  tags = {
    Name = "GitLab Runner"
  }
}

# Sortie de l'adresse IP publique de l'instance
output "gitlab_runner_public_ip" {
  value = aws_instance.gitlab_runner.public_ip
}
