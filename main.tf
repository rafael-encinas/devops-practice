terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

locals {
  key_name = "your-key"
  private_key_path = "/path/to/your/key/your-key.pem"
  file_destination =  "/tmp/your-key.pem"
  chmod_command = "chmod 400 '/tmp/your-key.pem'"
}

provider "aws" {
  region = "us-west-1"
}

resource "aws_vpc" "main_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main_vpc"
  }
}

resource "aws_internet_gateway" "devops-igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "devops-igw"
  }
}

resource "aws_eip" "devops_elastic_ip" {
  depends_on = [ aws_internet_gateway.devops-igw ]
}

resource "aws_nat_gateway" "devops-natgw" {
  allocation_id = aws_eip.devops_elastic_ip.id
  subnet_id     = aws_subnet.devops-public-subnet-1b.id

  tags = {
    Name = "devops-natgw"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.devops-igw]
}

resource "aws_subnet" "devops-public-subnet-1b" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-1b"

  tags = {
    Name = "devops-public-subnet-1b"
  }
}

resource "aws_subnet" "devops-public-subnet-1c" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.5.0/24"
  availability_zone = "us-west-1c"

  tags = {
    Name = "devops-public-subnet-1c"
  }
}

resource "aws_route_table" "devops-public-rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.devops-igw.id
  }

  tags = {
    Name = "devops-public-rt"
  }
}

resource "aws_route_table_association" "devops-associate-public-subnets-1b" {
  subnet_id      = aws_subnet.devops-public-subnet-1b.id
  route_table_id = aws_route_table.devops-public-rt.id
}

resource "aws_route_table_association" "devops-associate-public-subnets-1c" {
  subnet_id      = aws_subnet.devops-public-subnet-1c.id
  route_table_id = aws_route_table.devops-public-rt.id
}

resource "aws_subnet" "devops-private-subnet-1b" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-west-1b"

  tags = {
    Name = "devops-private-subnet-1b"
  }
}

resource "aws_route_table" "devops-private-rt" {
  vpc_id = aws_vpc.main_vpc.id

  
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id =  aws_nat_gateway.devops-natgw.id
  }
  

  tags = {
    Name = "devops-private-rt"
  }
}

resource "aws_route_table_association" "devops-associate-private-subnets" {
  subnet_id      = aws_subnet.devops-private-subnet-1b.id
  route_table_id = aws_route_table.devops-private-rt.id
}

resource "aws_security_group" "devops-public-subnet-sg" {
  name        = "devops-public-subnet-sg"
  description = "Allow SSH inboud traffic and all outbound traffic"
  vpc_id      = aws_vpc.main_vpc.id

  tags = {
    Name = "devops-public-subnet-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.devops-public-subnet-sg.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 22
  ip_protocol = "tcp"
  to_port = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic" {
  security_group_id = aws_security_group.devops-public-subnet-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_security_group" "devops-alb-sg" {
  name        = "devops-alb-sg"
  description = "Allow all inbound and outbound traffic"
  vpc_id      = aws_vpc.main_vpc.id

  tags = {
    Name = "devops-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_all_inbound_traffic" {
  security_group_id = aws_security_group.devops-alb-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_egress_rule" "allow_all_outbound_traffic" {
  security_group_id = aws_security_group.devops-alb-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_security_group" "devops-private-subnet-sg" {
  name        = "devops-private-subnet-sg"
  description = "Allow SSH from bastion hostn, tcp from ALB, and all outbound traffic"
  vpc_id      = aws_vpc.main_vpc.id

  tags = {
    Name = "devops-private-subnet-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_alb" {
  security_group_id = aws_security_group.devops-private-subnet-sg.id
  referenced_security_group_id = aws_security_group.devops-alb-sg.id
  //cidr_ipv4 = aws_security_group.devops-alb-sg.
  from_port = 8080
  ip_protocol = "tcp"
  to_port = 8080
}

resource "aws_vpc_security_group_ingress_rule" "allow_bastion" {
  security_group_id = aws_security_group.devops-private-subnet-sg.id
  cidr_ipv4 = aws_subnet.devops-public-subnet-1b.cidr_block
  from_port = 22
  ip_protocol = "tcp"
  to_port = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_outbount_traffic_private" {
  security_group_id = aws_security_group.devops-private-subnet-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


resource "aws_instance" "devops_bastion_host" {
  ami           = "ami-08d4f6bbae664bd41"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  availability_zone = "us-west-1b"
  key_name = local.key_name
  vpc_security_group_ids = [aws_security_group.devops-public-subnet-sg.id]
  subnet_id = aws_subnet.devops-public-subnet-1b.id

provisioner "file" {
    source = local.private_key_path
    destination = local.file_destination

    connection {
      host = self.public_ip
      private_key = file(local.private_key_path)
      user = "ec2-user"
      type = "ssh"
      timeout = "2m"
    }
  }

  provisioner "remote-exec" {
    inline = [ 
      "echo 'Configuring key pair'",
      local.chmod_command
     ]
    connection {
      host = self.public_ip
      private_key = file(local.private_key_path)
      user = "ec2-user"
      type = "ssh"
      timeout = "2m"
    }
  }

  tags = {
    Name = "devops_bastion_host"
  }
}

resource "aws_instance" "devops_jenkins" {
  ami           = "ami-08d4f6bbae664bd41"
  instance_type = "t2.micro"
  availability_zone = "us-west-1b"
  key_name = local.key_name
  vpc_security_group_ids = [aws_security_group.devops-private-subnet-sg.id]
  subnet_id = aws_subnet.devops-private-subnet-1b.id

    provisioner "file" {
    source = "jenkins.yaml"
    destination = "/tmp/jenkins.yaml"

    connection {
      bastion_host = aws_instance.devops_bastion_host.public_ip
      bastion_private_key = file(local.private_key_path)
      bastion_user = "ec2-user"
      host = self.private_ip
      type = "ssh"
      user = "ec2-user"
      timeout = "2m"
      private_key = file(local.private_key_path)
    }
  }

  provisioner "remote-exec" {
    inline = [ 
      "echo 'Waiting until SSH is ready'",
      "echo 'Installing Ansible and running playbook'",
      "sudo yum install ansible -y",
      "ansible-playbook /tmp/jenkins.yaml",
      "echo 'Jenkins password:'",
      "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
     ]

    connection {
      bastion_host = aws_instance.devops_bastion_host.public_ip
      bastion_private_key = file(local.private_key_path)
      bastion_user = "ec2-user"
      host = self.private_ip
      type = "ssh"
      user = "ec2-user"
      timeout = "2m"
      private_key = file(local.private_key_path)
    }
  }

  tags = {
    Name = "devops_jenkins"
  }

  depends_on = [aws_nat_gateway.devops-natgw, aws_instance.devops_bastion_host]
}

resource "aws_lb" "devops-alb" {
  name               = "devops-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.devops-alb-sg.id]
  subnets            = [aws_subnet.devops-public-subnet-1b.id, aws_subnet.devops-public-subnet-1c.id]

  tags = {
    Environment = "development"
  }
}

resource "aws_lb_target_group" "devops-jenkins-tg" {
  name     = "devops-jenkins-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id

}

resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = aws_lb_target_group.devops-jenkins-tg.arn
  target_id        = aws_instance.devops_jenkins.id
  port             = 8080

}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.devops-alb.arn
  port              = "80"
  protocol          = "HTTP"


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.devops-jenkins-tg.arn
  }
}