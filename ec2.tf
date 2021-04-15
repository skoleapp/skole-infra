resource "aws_launch_configuration" "prod" {
  name_prefix          = "skole-prod-lc"
  image_id             = "ami-09509e8f8dea8ab83"
  instance_type        = "t2.small"
  user_data            = "#!/bin/bash\necho ECS_CLUSTER=skole-prod-cluster >> /etc/ecs/ecs.config"
  key_name             = "skole"
  security_groups      = [aws_security_group.prod.id]
  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "staging" {
  name_prefix          = "skole-staging-lc"
  image_id             = "ami-09509e8f8dea8ab83"
  instance_type        = "t2.small"
  user_data            = "#!/bin/bash\necho ECS_CLUSTER=skole-staging-cluster >> /etc/ecs/ecs.config"
  key_name             = "skole"
  security_groups      = [aws_security_group.staging.id]
  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eip" "prod" {
  tags = {
    Name = "skole-prod-ip"
  }
}

resource "aws_eip" "staging" {
  tags = {
    Name = "skole-staging-ip"
  }
}
