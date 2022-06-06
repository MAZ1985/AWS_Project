# Assign global variables.
variable "awsvars" {
    type = map
    default = {
    region = "us-west-2"
    vpc = "vpc-0214c210c1003a768"
    ami = "ami-0ca285d4c2cda3300"
    itype = "t2.micro"
    subnet = "subnet-083018511d96dd640"
    publicip = true
    keyname = "giteaserver"
    secgroupname = "azsecgroup"
   }
}

provider "aws" {
    region = lookup(var.awsvars, "region")
}

# Create security group for the new instance to used.
resource "aws_security_group" "azsecgroup" {
    name = "azsecgroup"
    description = "Purposely for learning"
    vpc_id = lookup(var.awsvars, "vpc")

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    ingress {
        from_port = 3000
        to_port = 3000
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    egress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    lifecycle {
        create_before_destroy = true
    }
}
    
# Create an AWS instance.
resource "aws_instance" "learn_vm" {
    ami = lookup(var.awsvars, "ami")
    instance_type = lookup(var.awsvars, "itype")
    subnet_id = lookup(var.awsvars, "subnet")
    associate_public_ip_address = lookup(var.awsvars, "publicip")
    key_name = lookup(var.awsvars, "keyname")

# Need to used vpc_security_group_ids instead of security_groups , this mentioned 
# in https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
# otherwise there is an error mentioning "InvalidGroup.NotFound"
    vpc_security_group_ids = [ aws_security_group.azsecgroup.id ]
#    security_groups = [ "azsecgroup" ]

    user_data = file("install_gitea.tpl")

    tags= {
      Name = "learn_vm"
    }
    depends_on = [ aws_security_group.azsecgroup ]
}

# Create Elastic IP to make it static and no changes of Public IP after reboot/shutdown.
resource "aws_eip" "learn_vm" {
    vpc      = true
    instance = aws_instance.learn_vm.id
    tags= {
      Name = "learn_vm"
    }
}

#resource "aws_subnet" "main" {
#  vpc_id     = lookup(var.awsvars, "vpc")
#  cidr_block = "172.31.0.0/16"

#  tags = {
#    Name = "Main"
#  }
#}

resource "aws_alb" "terraformlb" {  
  name            = "terraformlb"
  subnets         = [ "subnet-04abb2661f17e3e89", "subnet-083018511d96dd640", "subnet-0acb95410f16e0efd", "subnet-0f09bc07081a24426"]
  security_groups = ["${aws_security_group.azsecgroup.id}"]
  tags = {    
    Name    = "terraformlb"    
  }
}

resource "aws_alb_target_group" "group" {
  name     = "terraform-aws"
  port     = 80
  protocol = "HTTP"
  vpc_id   = lookup(var.awsvars, "vpc")
  stickiness {
    type = "lb_cookie"
  }
  # Alter the destination of the health check to be the login page.
  health_check {
    path = "/"
    port = 3000
  }
}

resource "aws_alb_listener" "listener_http" {
  load_balancer_arn = "${aws_alb.terraformlb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.group.arn}"
    type             = "forward"
  }
}

resource "aws_alb_target_group_attachment" "terratest" {
  target_group_arn = "${aws_alb_target_group.group.arn}"
  target_id        = "${aws_instance.learn_vm.id}"  
  port             = 3000
}