/*
Auth : Maleesha Gimshan
Date : 2025-04-17
*/

provider "aws" {
  region     = "us-east-1"
  access_key = "xxxxxxxxxxxxxxxxxxxxxxxx"                # Replace with your IAM access key
  secret_key = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"         # Replace with your IAM secret key
}

# -----------------  vpc and subnets --------------------------------------------------------

# VPC
resource "aws_vpc" "maleeshavpc02" {
  cidr_block = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_support   = true
  enable_dns_hostnames = false
  ipv6_cidr_block      = null  # Explicitly disable IPv6
  tags = {
    Name = "maleeshavpc02"
  }
}

# public subnet 01
resource "aws_subnet" "public_subnet_01" {
  vpc_id = aws_vpc.maleeshavpc02.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "public_subnet_01"
  }
}

# public subnet 02 (Requred for high availability of the ALB)
resource "aws_subnet" "public_subnet_02" {
  vpc_id = aws_vpc.maleeshavpc02.id
  cidr_block = "192.168.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "public_subnet_02"
  }
}

# private subnet
resource "aws_subnet" "private_subnet_01" {
  vpc_id = aws_vpc.maleeshavpc02.id
  cidr_block = "192.168.3.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "private_subnet_01"
  }
}
# -----------------  internet gateway --------------------------------------------------------

# internet gateway
resource "aws_internet_gateway" "maleesha_IGW_02" {
    vpc_id = aws_vpc.maleeshavpc02.id
    tags = {
      Name = "maleesha_IGW_02"
    }
}

# -----------------  Nat gateway and elsatic ip --------------------------------------------------------

# elastic ip
resource "aws_eip" "ElasticIP_for_nat" {
  domain = "vpc"
  tags = {
    Name = "eip_for_nat" 
  }
}

# nat gateway
resource "aws_nat_gateway" "web_nat" {
  allocation_id = aws_eip.ElasticIP_for_nat.id
  subnet_id = aws_subnet.public_subnet_01.id
  tags = {
    Name = "web_nat_gateway"
  }
  depends_on = [ aws_internet_gateway.maleesha_IGW_02 ]
}

# -----------------  route tables and rules --------------------------------------------------------

# public route table
resource "aws_route_table" "my_public_route_01" {
  vpc_id = aws_vpc.maleeshavpc02.id 
  tags = {
    Name = "my_public_route_01"
  }
  # assign the internet gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.maleesha_IGW_02.id
  }
}

# private route table
resource "aws_route_table" "my_private_route_01" {
  vpc_id = aws_vpc.maleeshavpc02.id 
  tags = {
    Name = "my_private_route_01"
  }
  # assign the nat gateway
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.web_nat.id
  }
}

# Associate the Public Subnet 01 with the public Route Table
resource "aws_route_table_association" "public_subnet_association_01" {
  subnet_id = aws_subnet.public_subnet_01.id
  route_table_id = aws_route_table.my_public_route_01.id
}

# Associate the Public Subnet 02 with the public Route Table
resource "aws_route_table_association" "public_subnet_association_02" {
  subnet_id = aws_subnet.public_subnet_02.id
  route_table_id = aws_route_table.my_public_route_01.id
}

# Associate the private Subnet with the private Route Table
resource "aws_route_table_association" "private_subnet_association" {
  subnet_id = aws_subnet.private_subnet_01.id
  route_table_id = aws_route_table.my_private_route_01.id
}

# -----------------  Security Groups and rules --------------------------------------------------------

# security group for bastion server
resource "aws_security_group" "bastion_SG" {
  vpc_id = aws_vpc.maleeshavpc02.id
  name = "bastion_SG"
  description = "allow ssh for bastion"
  tags = {
    Name = "bastion_SG"
  }
}

# security group for web server
resource "aws_security_group" "web_SG" {
  vpc_id = aws_vpc.maleeshavpc02.id
  name = "web_SG"
  description = "allow http/https traffics" 
  tags = {
    Name = "web_SG"
  }  
}

# security group for ALB
resource "aws_security_group" "ALB_SG" {
  vpc_id = aws_vpc.maleeshavpc02.id
  name = "ALB_SG"
  description = "allow http/https traffics for ALB" 
  tags = {
    Name = "ALB_SG"
  }  
}

# inbound SG rule for bastion server - ssh
resource "aws_vpc_security_group_ingress_rule" "allow_22_01" {
  security_group_id = aws_security_group.bastion_SG.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

# inbound SG rule for web server -ssh
resource "aws_vpc_security_group_ingress_rule" "allow_22_02" {
  security_group_id = aws_security_group.web_SG.id
  referenced_security_group_id = aws_security_group.bastion_SG.id
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

# inbound SG rule for web server - http
resource "aws_vpc_security_group_ingress_rule" "allow_http_01" {
  security_group_id = aws_security_group.web_SG.id
  referenced_security_group_id = aws_security_group.bastion_SG.id
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

# inbound SG rule for web server - http
resource "aws_vpc_security_group_ingress_rule" "allow_http_02" {
  security_group_id = aws_security_group.web_SG.id
  referenced_security_group_id = aws_security_group.ALB_SG.id
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

# inbound SG rule for ALB - http
resource "aws_vpc_security_group_ingress_rule" "allow_http_03" {
  security_group_id = aws_security_group.ALB_SG.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

# outbound SG rule for bastion server
resource "aws_vpc_security_group_egress_rule" "allow_full_outbound_01" {
  security_group_id = aws_security_group.bastion_SG.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "-1"
}

# outbound SG rule for web server
resource "aws_vpc_security_group_egress_rule" "allow_full_outbound_02" {
  security_group_id = aws_security_group.web_SG.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "-1"
}

# outbound SG rule for ALB
resource "aws_vpc_security_group_egress_rule" "allow_full_outbound_03" {
  security_group_id = aws_security_group.ALB_SG.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "-1"
}

# ----------------- Bastion EC2 --------------------------------------------------------

resource "aws_instance" "bastion_server" {
    ami = "ami-0c15e602d3d6c6c4a"
    instance_type = "t2.micro"
    
    vpc_security_group_ids = [ 
      aws_security_group.bastion_SG.id 
    ]
    
    subnet_id = aws_subnet.public_subnet_01.id
    key_name = "my_key_01"
    
    # assosiate public ip with the intance 
    associate_public_ip_address = true

    # will delete the os disk when terminating the intance 
    root_block_device { delete_on_termination = true }

    tags = {
      Name = "bastion_server"
    }
}

# ----------------- Web EC2 --------------------------------------------------------

resource "aws_instance" "web_server_01" {
    ami = "ami-0c15e602d3d6c6c4a"
    instance_type = "t2.micro"
    
    vpc_security_group_ids = [ 
      aws_security_group.web_SG.id 
    ]
    
    subnet_id = aws_subnet.private_subnet_01.id
    key_name = "my_key_01"
    
    # do not assosiate public ip with the intance 
    associate_public_ip_address = false

    # will delete the os disk when terminating the intance 
    root_block_device { delete_on_termination = true }

    tags = {
      Name = "web_server_01"
    }
    
    # userdata script 
    user_data = file("ec2__web_user_data.sh")
}

resource "aws_instance" "web_server_02" {
    ami = "ami-0c15e602d3d6c6c4a"
    instance_type = "t2.micro"
    
    vpc_security_group_ids = [ 
      aws_security_group.web_SG.id 
    ]
    
    subnet_id = aws_subnet.private_subnet_01.id
    key_name = "my_key_01"
    
    # do not assosiate public ip with the intance 
    associate_public_ip_address = false

    # will delete the os disk when terminating the intance 
    root_block_device { delete_on_termination = true }

    tags = {
      Name = "web_server_02"
    }
    
    # userdata script 
    user_data = file("ec2__web_user_data.sh")
}

# ----------------- Target group (ALB) --------------------------------------------------------

# target group
resource "aws_lb_target_group" "mytargetgroup01" {
  name = "mytargetgroup01"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.maleeshavpc02.id 

  health_check {
    path = "/"
    protocol = "HTTP"
    interval = 30
    timeout  = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# assign web server 1 in to the target group
resource "aws_lb_target_group_attachment" "my_target_group_01_attachements_01" {
  target_group_arn = aws_lb_target_group.mytargetgroup01.arn
  target_id = aws_instance.web_server_01.id
  port = 80
}

# assign web server 2 in to the target group
resource "aws_lb_target_group_attachment" "my_target_group_01_attachements_02" {
  target_group_arn = aws_lb_target_group.mytargetgroup01.arn
  target_id = aws_instance.web_server_02.id
  port = 80
}

# ----------------- ALB and listners --------------------------------------------------------

# ALB
resource "aws_lb" "myALB" {
  name = "myALB"
  load_balancer_type = "application"
  internal = false
  security_groups = [
    aws_security_group.ALB_SG.id
  ]
  subnets = [
    aws_subnet.public_subnet_01.id,
    aws_subnet.public_subnet_02.id
  ]
}

# Lister for http
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.myALB.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.mytargetgroup01.arn
  }
}