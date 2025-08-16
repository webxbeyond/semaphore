########################
# Provider & Variables
########################

provider "aws" {
  region = "ap-southeast-1"
}

variable "key_name" {
  description = "SSH key pair name to access the instance (must exist in AWS)"
  type        = string
  default     = "passless"
}

########################
# Latest Ubuntu AMI (22.04 LTS)
########################

data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

########################
# Security Group Rules
########################

locals {
  ingress_rules = [
    # SSH
    { description = "SSH (restricted)", from = 22, to = 22, protocol = "tcp", cidr = "0.0.0.0/0" },

    # Netdata
    { description = "Netdata", from = 19999, to = 19999, protocol = "tcp", cidr = "0.0.0.0/0" },

    # AdGuard DNS
    { description = "DNS TCP", from = 53, to = 53, protocol = "tcp", cidr = "0.0.0.0/0" },
    { description = "DNS UDP", from = 53, to = 53, protocol = "udp", cidr = "0.0.0.0/0" },

    # DHCP
    { description = "DHCP Server UDP", from = 67, to = 67, protocol = "udp", cidr = "0.0.0.0/0" },
    { description = "DHCP Client UDP", from = 68, to = 68, protocol = "udp", cidr = "0.0.0.0/0" },

    # Adguard Admin Panel
    { description = "HTTP", from = 80, to = 80, protocol = "tcp", cidr = "0.0.0.0/0" },
    { description = "HTTPS", from = 443, to = 443, protocol = "tcp", cidr = "0.0.0.0/0" },
    { description = "HTTPS", from = 3000, to = 3000, protocol = "tcp", cidr = "0.0.0.0/0" },
    

    # DoT / DoQ
    { description = "DoT TCP", from = 853, to = 853, protocol = "tcp", cidr = "0.0.0.0/0" },
    { description = "DoT UDP", from = 853, to = 853, protocol = "udp", cidr = "0.0.0.0/0" },
    { description = "DoQ UDP 784", from = 784, to = 784, protocol = "udp", cidr = "0.0.0.0/0" },
    { description = "DoQ UDP 8853", from = 8853, to = 8853, protocol = "udp", cidr = "0.0.0.0/0" },

    # DNSCrypt
    { description = "DNSCrypt TCP", from = 5443, to = 5443, protocol = "tcp", cidr = "0.0.0.0/0" },
    { description = "DNSCrypt UDP", from = 5443, to = 5443, protocol = "udp", cidr = "0.0.0.0/0" },

    # WireGuard
    { description = "WireGuard UDP", from = 51820, to = 51820, protocol = "udp", cidr = "0.0.0.0/0" },
    { description = "WireGuard Admin TCP", from = 51821, to = 51821, protocol = "tcp", cidr = "0.0.0.0/0" },
  ]
}

########################
# Security Group Resource
########################

resource "aws_security_group" "naw" {
  name        = "naw-host-sg"
  description = "Allow required ports for naw services"

  dynamic "ingress" {
    for_each = local.ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = ingress.value.protocol
      cidr_blocks = [ingress.value.cidr]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

########################
# EC2 Instance
########################

resource "aws_instance" "naw" {
  ami                    = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.naw.id]
  key_name               = var.key_name

  tags = {
    Name = "NAW"
  }
}

########################
# Output
########################

output "instance_public_ip" {
  description = "The public IP address of the NAW instance"
  value       = aws_instance.naw.public_ip
}
