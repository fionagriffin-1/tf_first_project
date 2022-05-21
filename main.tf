terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
 
}

  
  #Create VPC
resource "aws_vpc" "tf-vpc" {
  cidr_block = "10.0.0.0/16"
 tags = {
    Name = "prod_vpc"
  }
  }






  #Create IGW
  resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.tf-vpc.id
}

#Create route table

resource "aws_route_table" "prod_route_table" {
  vpc_id = aws_vpc.tf-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod"
  }
}


variable subnet_prefix {
  type        = string
  default     = ""
  description = "cidr block for the subnet"
}


#Create Subnet 

resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.tf-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod-subnet"
  }
}

#Associate subnet with route table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod_route_table.id
}

#Create Security Group

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.tf-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
      description = "HTTP"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
   }
   ingress {
     description = "SSH"
     from_port   = 22
     to_port     = 22
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
   }
  
   egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
   
  }

  tags = {
    Name = "allow_web"
  }
}

 # Create a network interface with an ip in the subnet that was created in step 4
  resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}
# Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  depends_on                = [aws_internet_gateway.gw]
}


resource "aws_instance" "web_server" {
  ami           = "ami-0022f774911c1d690"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
   key_name          = "tf"

  tags = {
   Name = "FIONA_ENV"

  }
   network_interface {
   device_index         = 0
     network_interface_id = aws_network_interface.web-server-nic.id
   }

 user_data =  <<-EOF
                !/bin/bash
                 sudo apt update -y
                 sudo apt install apache2 -y
                 sudo systemctl start apache2
                 sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                 EOF
  

  

}
