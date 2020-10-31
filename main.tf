terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.13.0"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

resource "tls_private_key" "pkey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "spotkey" {
  key_name   = "spotkey"
  public_key = tls_private_key.pkey.public_key_openssh
}

resource "aws_vpc" "test-env" {
  cidr_block           = "10.100.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "subnet-uno" {
  # creates a subnet
  cidr_block        = cidrsubnet(aws_vpc.test-env.cidr_block, 8, 1)
  vpc_id            = aws_vpc.test-env.id
  availability_zone = "us-east-1a"
}

resource "aws_security_group" "ingress-ssh-test" {
  name   = "allow-ssh-sg"
  vpc_id = aws_vpc.test-env.id

  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]

    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ingress-http-test" {
  name   = "allow-http-sg"
  vpc_id = aws_vpc.test-env.id

  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]

    from_port = 80
    to_port   = 80
    protocol  = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ingress-https-test" {
  name   = "allow-https-sg"
  vpc_id = aws_vpc.test-env.id

  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]

    from_port = 443
    to_port   = 443
    protocol  = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_eip" "ip-test-env" {
  instance = aws_spot_instance_request.nebula_spot[0].spot_instance_id
  vpc      = true
}

resource "aws_internet_gateway" "test-env-gw" {
  vpc_id = aws_vpc.test-env.id
}

resource "aws_route_table" "route-table-test-env" {
  vpc_id = aws_vpc.test-env.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test-env-gw.id
  }
}

resource "aws_route_table_association" "subnet-association" {
  subnet_id      = aws_subnet.subnet-uno.id
  route_table_id = aws_route_table.route-table-test-env.id
  depends_on = [aws_route_table.route-table-test-env, aws_subnet.subnet-uno]
}

resource "aws_spot_instance_request" "nebula_spot" {
  ami                    = "ami-0817d428a6fb68645"
  spot_price             = "0.01"
  instance_type          = "t3a.micro"
  count                  =  1
  spot_type              = "one-time"
  block_duration_minutes = "120"
  wait_for_fulfillment   = "true"
  key_name               = "spotkey"
  tags = {
    "Env"      = "Private"
    "Location" = "Secret"
  }
  security_groups = [aws_security_group.ingress-ssh-test.id, aws_security_group.ingress-http-test.id,
  aws_security_group.ingress-https-test.id]
  subnet_id = aws_subnet.subnet-uno.id
}

resource "aws_spot_instance_request" "openvpn_spot" {
  ami                    = "ami-0817d428a6fb68645"
  spot_price             = "0.004"
  instance_type          = "t3a.nano"
  count                  =  1
  spot_type              = "one-time"
  block_duration_minutes = "120"
  wait_for_fulfillment   = "true"
  key_name               = "spotkey"
  tags = {
    "Env"      = "Private"
    "Location" = "Secret"
  }
  security_groups = [aws_security_group.ingress-ssh-test.id, aws_security_group.ingress-http-test.id,
  aws_security_group.ingress-https-test.id]
  subnet_id = aws_subnet.subnet-uno.id
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_spot_instance_request.nebula_spot[0].spot_instance_id
  allocation_id = aws_eip.exampleip.id

  depends_on = [aws_spot_instance_request.nebula_spot, aws_eip.exampleip]
}


resource "aws_eip" "exampleip" {
  vpc = true
}
#volume attachment
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.example.id
  instance_id = aws_spot_instance_request.nebula_spot[0].spot_instance_id
}

resource "aws_ebs_volume" "example" {
  availability_zone = "us-east-1a"
  size              = 1
}

