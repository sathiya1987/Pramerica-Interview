provider aws
  { region="us-west-2"
    access_key="${var.aws_access_key}"

    secret_key="${var.aws_secret_key}"
    token ="${var.aws_token}"
 }
resource "aws_vpc" "stage" {
  cidr_block = "${var.vpc_cidr}
  tags {
        Name = "prudential-vpc"
    }
}
resource "aws_subnet" "subnets" {
  count             = "${length(var.vpc_subnet_cidr)}"
  vpc_id            = "${aws_vpc.stage.id}"
  cidr_block        = "${element(var.vpc_subnet_cidr, count.index)}"
  availability_zone = "${element(var.vpc_subnet_azs, count.index)}"

  tags {
    Name = "${element(var.vpc_subnet_names, count.index)}"
  }
}
resource "aws_internet_gateway" "web-prudential" {
    vpc_id = "${aws_vpc.stage.id}"
}
resource "aws_route_table" "prudential-route" {
  vpc_id = "${aws_vpc.stage.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.web-prudential.id}"
  }
}

resource "aws_route_table_association" "subnets" {
  count          = "${length(var.vpc_subnet_cidr)}"
  subnet_id      = "${element(aws_subnet.subnets.*.id, count.index)}"
  route_table_id = "${aws_route_table.prudential-route.id}"
}


resource "aws_security_group" "websg" {
name = "security_group_for_web_server"
ingress {
from_port = 80
to_port = 80
protocol = "tcp"
cidr_blocks = ["192.0.0.0/24"]
}
ingress {
from_port = 22
to_port = 22
protocol = "tcp"
cidr_blocks = ["192.0.0.0/24"]
}

  egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
   }
  vpc_id ="${aws_vpc.stage.id}"
}
resource "aws_security_group" "elbsg" {
name = "security_group_for_elb"
ingress {
from_port = 80
to_port = 80
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}

  egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
  vpc_id ="${aws_vpc.stage.id}"
}
resource "aws_launch_configuration" "prudential-lc" {
  image_id = "${var.ami_id}"
  instance_type = "${var.instance_type}"
  security_groups = ["${aws_security_group.websg.id}"]
  key_name = "${var.key_name}"
  name = "prudential-lc"

}
resource "aws_autoscaling_group" "prudential-asg" {
  name = "prudential-asg"
  max_size = 12
  min_size = 9
  desired_capacity = 9
  force_delete= true
  launch_configuration = "${aws_launch_configuration.prudential-lc.name}"
  vpc_zone_identifier= ["${aws_subnet.subnets.*.id}"]
  health_check_grace_period = 300
  health_check_type = "ELB"
  enabled_metrics=["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupTotalInstances"]
  metrics_granularity="1Minute"
  protect_from_scale_in="true"
  load_balancers = ["${aws_elb.prudential-elb.id}"]
  tag {
    key="Name"
    value="prudential-demo"
    propagate_at_launch = true
  }
tag {
    key="Env"
    value="Dev"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "up" {
  name = "prudential-scaleout"
  scaling_adjustment = 3
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.prudential-asg.name}"

}
resource "aws_autoscaling_policy" "down" {
  name = "prudential-scalein"
  scaling_adjustment = -3
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.prudential-asg.name}"
}
resource "aws_cloudwatch_metric_alarm" "high" {
    alarm_name = "prudential-alarm-high"
    comparison_operator = "GreaterThanOrEqualToThreshold"

evaluation_periods = "2"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "120"
    statistic = "Average"
    threshold = "90"
    dimensions {
        AutoScalingGroupName = "${aws_autoscaling_group.prudential-asg.name}"
    }
    alarm_description = "This metric monitor ec2 cpu utilization"
    alarm_actions = ["${aws_autoscaling_policy.up.arn}"]

}
resource "aws_cloudwatch_metric_alarm" "low" {
    alarm_name = "prudential-alarm-low"
    comparison_operator = "LessThanThreshold"
    evaluation_periods = "2"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "120"
    statistic = "Average"
    threshold = "40"
    dimensions {
        AutoScalingGroupName = "${aws_autoscaling_group.prudential-asg.name}"
    }
    alarm_description = "This metric monitor ec2 cpu utilization"
    alarm_actions = ["${aws_autoscaling_policy.down.arn}"]

}
resource "aws_elb" "prudential-elb" {
name = "prudential-web-elb"
security_groups = ["${aws_security_group.elbsg.id}"]
subnets = ["${aws_subnet.subnets.*.id}"]
listener {
instance_port = 80
instance_protocol = "http"
lb_port = 80
lb_protocol = "http"
}
health_check {
healthy_threshold = 2
unhealthy_threshold = 2
timeout = 3
target = "HTTP:80/"
interval = 30
}
cross_zone_load_balancing = true
idle_timeout = 300
connection_draining = true
connection_draining_timeout = 300
tags {
Name ="prudential-web-elb"
}
}
resource "aws_lb_cookie_stickiness_policy" "cookie_stickness" {
name = "cookiestickness"
load_balancer = "${aws_elb.prudential-elb.id}"
lb_port = 80
cookie_expiration_period = 600
}


provisioner "local-exec" {
   command = "ansible-playbook -i ec2.py  -e tag_Env_Dev web-site.yml"
 }
}


