provider "aws" {
  region     = "us-east-1"
  access_key = ""
  secret_key = ""
}

resource "aws_instance" "maleesha01" {
    ami = "ami-0c15e602d3d6c6c4a"
    instance_type = "t2.micro"
    
    security_groups = [
        "sg-09713cca85a041b5a",
        "sg-0688fd78d7cc48c59",
        "sg-07fff07fe923c3bc2"
    ]
    
    subnet_id = "subnet-06455728e09e93034"
    key_name = "my_key_01"
    
    # assosiate public ip with the intance 
    associate_public_ip_address = true

    # will delete the os disk when terminating the intance 
    root_block_device { delete_on_termination = true }
}



