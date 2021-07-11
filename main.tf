provider "aws" {
  region = "eu-central-1"
}
#---------------------------------------------------------------------------------
data "aws_availability_zones" "available" {}
data "aws_ami" "latest_ubuntu" {
  owners      = ["099720109477"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}
#---------------------------------------------------------------------------------
resource "aws_security_group" "stone" {
  name        = "Security"
  description = "Security"

  dynamic "ingress" {
    for_each = ["80", "443", "22"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }
  tags = {
    Name  = "Group"
    Owner = "Yura K"
  }
}
#---------------------------------------------------------------------------------
resource "aws_launch_configuration" "web_stone" {
  name_prefix     = "hight-aviability-"
  image_id        = data.aws_ami.latest_ubuntu.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.stone.id]
  user_data       = file("server.sh")
  #key_name        = "aws-pair-key"--------------<-<-<-

  lifecycle {
    create_before_destroy = true
  }
}
#---------------------------------------------------------------------------------
resource "aws_autoscaling_group" "stone" {
  name                 = "ASG-${aws_launch_configuration.web_stone.name}"
  launch_configuration = aws_launch_configuration.web_stone.id
  min_size             = 1
  max_size             = 5
  min_elb_capacity     = 1
  desired_capacity     = 1
  vpc_zone_identifier  = [aws_default_subnet.default_az-a.id, aws_default_subnet.default_az-b.id]
  health_check_type    = "ELB"
  load_balancers       = [aws_elb.stone.name]

  dynamic "tag" {
    for_each = {
      Name   = "auto_scaling_stone"
      Owner  = "Japan"
      TAGKEY = "TAGVALUE"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "server" {
  name = "sever-scaling-policy"

  autoscaling_group_name = aws_autoscaling_group.stone.name
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 40.0
  }
}

resource "aws_elb" "stone" {
  name               = "stone-elb"
  availability_zones = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  security_groups    = [aws_security_group.stone.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  cross_zone_load_balancing = true
  tags = {
    Name = "stone-load-balancer"
  }
}
#---------------------------------------------------------------------------------
resource "aws_default_subnet" "default_az-a" {
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "Default subnet 1"
  }
}

resource "aws_default_subnet" "default_az-b" {
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "Default subnet 2"
  }
}
#---------------------------------------------------------------------------------
output "web-loadbalancer_url" {
  value = aws_elb.stone.dns_name
}
