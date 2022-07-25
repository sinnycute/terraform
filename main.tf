terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.8.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"

}
# Creating a new VPC
resource "aws_vpc" "my_vpc" {
  cidr_block       = "192.168.0.0/16"
  enable_dns_hostnames = true
  
  tags = {
    Name = "wordpress_rds_vpc"
  }
  
}

# Creating Public Subnet for Wordpress
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "192.168.5.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "public_subnet"
  }
  availability_zone = "ap-south-1a"
}

# Creating Private Subnet for database
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "192.168.6.0/24"
  
  tags = {
    Name = "private_subnet"
  }
  availability_zone = "ap-south-1b"
}

# Creating Database Subnet group for RDS under our VPC
resource "aws_db_subnet_group" "front_backend" {
  name       = "db_subnet1"
  subnet_ids = [aws_subnet.private_subnet.id, aws_subnet.public_subnet.id ]

  tags = {
    Name = "front_backend"
  }
}
# Creating Public Facing Internet Gateway
resource "aws_internet_gateway" "public_internet_gw" {
  vpc_id =  aws_vpc.my_vpc.id

  tags = {
    Name = "public_facing_internet_gateway"
  }
}

# Allowing default route table to go to Internet Gateway 
resource "aws_default_route_table" "gw_route" {
  default_route_table_id = aws_vpc.my_vpc.default_route_table_id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.public_internet_gw.id
    }

  tags = {
    Name = "gw_route"
  }
}

# Associating Public Subnet 
resource "aws_route_table_association" "associate_subnet1" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_default_route_table.gw_route.id
}

# Creating a new security group for public subnet 
resource "aws_security_group" "SG_public_subnet" {
  name        = "WordPress_security_group"
  description = "Allow SSH and HTTP"
  vpc_id      =  aws_vpc.my_vpc.id                   

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 ingress {
    description = "HTTP from VPC"
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

# Creating a new security group for private subnet 
resource "aws_security_group" "SG_private_subnet_" {
  name        = "sql_security_group"
  description = "sql"
  vpc_id      =  aws_vpc.my_vpc.id                   

  ingress {
    description = "sql Port"
    from_port   = 3306
    to_port     = 3306
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
# EC2 instance with Wordpress installation
resource "aws_instance" "WEB" {
  depends_on = [aws_internet_gateway.public_internet_gw]
  ami           = "ami-006d3995d3a6b963b"
  instance_type = "t2.micro"
   key_name = "terra-pro"
  subnet_id = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.SG_public_subnet.id]
  tags = {
     Name = "WEB"
  } 

  user_data = <<EOF
		 #! /bin/bash
             sudo yum install httpd php php-mysql -y -q
             sudo cd /var/www/html
             echo "Welcome" > hi.html
             sudo wget https://wordpress.org/wordpress-5.1.1.tar.gz
             sudo tar -xzf wordpress-5.1.1.tar.gz
             sudo cp -r wordpress/* /var/www/html/
             sudo rm -rf wordpress
             sudo rm -rf wordpress-5.1.1.tar.gz
             sudo chmod -R 755 wp-content
             sudo chown -R apache:apache wp-content
             sudo wget https://s3.amazonaws.com/bucketforwordpresslab-donotdelete/htaccess.txt
             sudo mv htaccess.txt .htaccess
             sudo systemctl start httpd
             sudo systemctl enable httpd 
      EOF

 provisioner "local-exec" {
  command = "echo ${aws_instance.WEB.public_ip} > publicIP.txt"
 }

}

# Launching RDS db instance
resource "aws_db_instance" "RDS" {
  allocated_storage    = 20
  max_allocated_storage = 100
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7.22"
  instance_class       = "db.t2.micro"
  db_name                 = "RDS"
  username             = "apeksh"
  password             = "apeksh1234"
  parameter_group_name = "default.mysql5.7"
  publicly_accessible = false
  db_subnet_group_name = aws_db_subnet_group.front_backend.name
  vpc_security_group_ids = [aws_security_group.SG_private_subnet_.id]
  skip_final_snapshot = true 

provisioner "local-exec" {
  command = "echo ${aws_db_instance.RDS.endpoint} > DB_host.txt"
    }
}
