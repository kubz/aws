provider "aws" {
  region  = var.region
  profile = "source"

  assume_role {
    role_arn    = var.target-arn
    external_id = var.external_id
  }

  default_tags {
    tags = {
      Environment = "Test"
      Service     = "automation"
      Name        = "automation"
    }
  }
}


resource "aws_vpc" "my_vpc" {
  cidr_block           = var.vpc-cidr
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my_vpc.id

}

# Create Public Subnet 1
# terraform aws create subnet
resource "aws_subnet" "public-subnet-1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = var.Public_Subnet_1
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true
}


resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

}

resource "aws_route_table_association" "public-subnet-1-route-table-association" {
  subnet_id      = aws_subnet.public-subnet-1.id
  route_table_id = aws_route_table.public-route-table.id
}

# Create Private Subnet 1
# terraform aws create subnet
resource "aws_subnet" "private-subnet-1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = var.Private_Subnet_1
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false
}


// =================== SSH
// Generate the SSH keypair that we’ll use to configure the EC2 instance.
// After that, write the private key to a local file and upload the public key to AWS
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "private_key" {
  filename          = "${var.key_name}.pem"
  sensitive_content = tls_private_key.key.private_key_pem
  file_permission   = "0400"
}
resource "aws_key_pair" "key_pair" {
  key_name   = var.key_name
  public_key = tls_private_key.key.public_key_openssh
}


// =================== SECURITY GROUP
resource "aws_security_group" "ssh-security-group" {
  name        = "SSH Security group"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description = "SSH from Internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh-location]
  }

  ingress {
    description = "port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.ssh-location]
  }

  # ingress {
  #   description      = "All TCP from Internet"
  #   from_port        = 0
  #   to_port          = 65535
  #   protocol         = "tcp"
  #   cidr_blocks      = ["0.0.0.0/0"]
  #   ipv6_cidr_blocks = ["::/0"]
  #   # cidr_blocks = [aws_vpc.my_vpc.cidr_block]
  # }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

// 


# data "aws_ami" "ubuntu" {
#   most_recent = true

#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
#   }

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }

#   owners = ["099720109477"]
# }

# resource "aws_key_pair" "ssh-key" {
#   key_name   = "ssh-key-mbp"
#   public_key = "<HERE SSH KEY>"
# }

resource "aws_instance" "example" {
  # ami           = data.aws_ami.ubuntu.id
  ami = "ami-065deacbcaac64cf2"

  instance_type = var.instance_type

  key_name = var.key_name

  vpc_security_group_ids = [aws_security_group.ssh-security-group.id]
  subnet_id              = aws_subnet.public-subnet-1.id

  associate_public_ip_address = true

  #user_data                   = "${data.template_file.provision.rendered}"
  #iam_instance_profile = "${aws_iam_instance_profile.some_profile.id}"
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      tags,
    ]
  }

  # Copies the ssh key file to home dir
  # Copies the ssh key file to home dir
  provisioner "file" {
    source      = "./${var.key_name}.pem"
    destination = "/home/ubuntu/${var.key_name}.pem"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${var.key_name}.pem")
      host        = self.public_ip
    }
  }

  //chmod key 400 on EC2 instance
  provisioner "remote-exec" {
    inline = ["chmod 400 ~/${var.key_name}.pem"]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${var.key_name}.pem")
      host        = self.public_ip
    }
  }

  depends_on = [aws_internet_gateway.gw]
  # network_interface {
  #   network_interface_id = aws_network_interface.foo.id
  #   device_index         = 0
  # }
  # tags = {
  #   Name = ""
  # }
}
