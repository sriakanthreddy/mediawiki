provider "aws" {
        region = "us-east-2"
        profile = "default"
}

# Creating Application Load Balancer

data "aws_subnet_ids" "sub_id" {

        vpc_id  = "${data.aws_vpc.my_id.id}"
}
# Gathering security group ids of defualt vpc

data "aws_security_group" "sec_id" {
        vpc_id  = "${data.aws_vpc.my_id.id}"
        name = "default"
}


# Creation of ALB

resource "aws_alb" "alb_front" {
        name            =       "mediawiki-alb"
        internal        =       false
        security_groups =       ["${data.aws_security_group.sec_id.id}"]
        subnets         =       ["${data.aws_subnet_ids.sub_id.ids}"]
        enable_deletion_protection = false
}
# Gathering the VPC details

data "aws_vpc" "my_id" {

        default = true
}

# Creation of the target group

resource "aws_alb_target_group" "alb_front_http" {
        name    = "mediawiki-targetgroup"
        port    = "80"
        vpc_id  = "${data.aws_vpc.my_id.id}"
        protocol        = "HTTP"
        health_check {
                path = "/mediawiki"
                port = "80"
                protocol = "HTTP"
                healthy_threshold = 2
                unhealthy_threshold = 2
                interval = 5
                timeout = 4
                matcher = "200-308"
        }
}

# Assignment of the EC2 instances to the target group

resource "aws_alb_target_group_attachment" "alb_backend-01_http" {
  target_group_arn = "${aws_alb_target_group.alb_front_http.arn}"
  count = 2
  target_id        = "${element(aws_instance.application.*.id, count.index)}"
  port             = 80
}

resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = "${aws_alb.alb_front.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.alb_front_http.arn}"
    type             = "forward"
  }
}

# Creating Instance

resource "aws_instance" "application" {
        ami = "ami-0b59bfac6be064b78"
        instance_type = "t2.micro"
        count = 2
        tags {
                Role = "app"
                Name="${format("application-%01d",count.index+1)}"
        }
        key_name = "Ramesh_Keys"
}

resource "aws_instance" "database" {
        ami = "ami-0b59bfac6be064b78"
        instance_type = "t2.micro"
        count = 1
        tags {
                Role = "db"
                Name="${format("database-%01d",count.index+1)}"
        }
        key_name = "Ramesh_Keys"
}

# Executing Ansible playbook post of infrastructure
resource "null_resource" "AnsiblePlaybook" {
  depends_on = ["aws_alb.alb_front"]
  provisioner "local-exec" {
    command = "sleep 40;ansible-playbook --inventory-file=terraform-inventory playbooks/main.yml"
  }
}
