resource "aws_autoscaling_group" "prod" {
  name                 = "skole-prod-asg"
  desired_capacity     = 1
  min_size             = 1
  max_size             = 2
  launch_configuration = aws_launch_configuration.prod.name
  vpc_zone_identifier  = [aws_subnet.prod_a.id, aws_subnet.prod_b.id, aws_subnet.prod_c.id]

  tag {
    key                 = "Name"
    value               = "skole-prod-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "staging" {
  name                 = "skole-staging-asg"
  desired_capacity     = 1
  min_size             = 1
  max_size             = 2
  launch_configuration = aws_launch_configuration.staging.name
  vpc_zone_identifier  = [aws_subnet.staging_a.id, aws_subnet.staging_b.id, aws_subnet.staging_c.id]

  tag {
    key                 = "Name"
    value               = "skole-staging-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
