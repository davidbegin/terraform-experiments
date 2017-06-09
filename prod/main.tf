provider "aws" {
  region = "us-east-1"
}

/* ============================== SERVERS AND LOAD BALANCERS ============================== */

resource "aws_launch_configuration" "ec2_launch_template" {
image_id        = "ami-40d28157"
instance_type   = "t2.micro"
security_groups = ["${aws_security_group.allow_all_traffic_on_server_port.id}"]


user_data = <<-EOF
            #!/bin/bash
            echo "triggerin new versions" > index.html
            nohup busybox httpd -f -p "${var.server_port}" &
            EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "autoscaling_setup" {
  launch_configuration = "${aws_launch_configuration.ec2_launch_template.id}"
  availability_zones   = ["${data.aws_availability_zones.all.names}"]

  load_balancers    = ["${aws_elb.begins_elb.name}"]
  health_check_type = "ELB"

  min_size = "${var.min_servers}"
  max_size = 10

  tag {
    key                 = "Name"
    value               = "begins-asg"
    propagate_at_launch = true
  }
}


resource "aws_elb" "begins_elb" {
  name               = "begins-asg"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  security_groups    = ["${aws_security_group.elb.id}"]

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = "${var.server_port}"
    instance_protocol = "http"
  }

  health_check {
    healthy_threshold   = "${var.min_servers}"
    unhealthy_threshold = "${var.min_servers}"
    timeout             = 3
    interval            = 30
    target              = "HTTP:${var.server_port}/"
  }
}

/* ============================== SECURITY GROUPS ============================== */


resource "aws_security_group" "allow_all_traffic_on_server_port" {
  name = "terraform-example-instance"

  ingress {
    from_port   = "${var.server_port}"
    to_port     = "${var.server_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "elb" {
  name = "begins-elb"

  ingress {
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

/* ============================== REMOTE STATE SETUP ============================== */

data "terraform_remote_state" "network" {
  backend = "s3"
  config {
    bucket = "begins_first_terraform_state_bucket"
    key    = "global/s3/terraform.tfstate"
    region = "us-east-1"
  }
}

/* ============================== VARIABLES, DATA AND OUTPUT ============================== */

variable "server_port" {
  description = "port the server is running on"
  default     = 8080
}

variable "min_servers" {
  description = "minimum number of servers desired to be running"
  default     = 2
}

data "aws_availability_zones" "all" {}

output "s3_bucket_arn" {
  value = "${data.terraform_remote_state.network.config}"
}

output "availability_zones" {
  value = "${data.aws_availability_zones.all.names}"
}

output "elb_dns_name" {
  value = "${aws_elb.begins_elb.dns_name}"
}
