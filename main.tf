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
              echo "Fuck yeah boys" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example" {
  launch_configuration = "${aws_launch_configuration.ec2_launch_template.id}"
  availability_zones   = ["${data.aws_availability_zones.all.names}"]

  min_size = 2
  max_size = 10

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}


resource "aws_elb" "begins_elb" {
  name               = "terraform-asg-example"
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = "${var.server_port}"
    instance_protocol = "http"
  }
}

/* ============================== SECURITY GROUPS ============================== */


resource "aws_security_group" "allow_all_traffic_on_server_port" {
  name = "terraform-example-instance"

  ingress {
    from_port = "${var.server_port}"
    to_port = "${var.server_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

/* ============================== VARIABLES, DATA AND OUTPUT ============================== */

variable "server_port" {
  description = "port the server is running on"
  default     = 8080
}

data "aws_availability_zones" "all" {}

output "availability_zones" {
  value = "${data.aws_availability_zones.all.names}"
}
