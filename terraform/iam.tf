resource "aws_iam_user" "infra" {
  name = "skole-infra-user"
}

resource "aws_iam_user" "monorepo" {
  name = "skole-monorepo-user"
}

resource "aws_iam_user" "backend_prod" {
  name = "skole-backend-prod-user"
}

resource "aws_iam_user" "backend_staging" {
  name = "skole-backend-staging-user"
}

resource "aws_iam_policy" "send_ses" {
  name   = "skole-send-ses"
  policy = data.aws_iam_policy_document.send_ses.json
}

resource "aws_iam_user_policy" "prod_buckets" {
  name   = "skole-prod-buckets-policy"
  user   = aws_iam_user.backend_prod.name
  policy = data.aws_iam_policy_document.prod_buckets.json
}

resource "aws_iam_user_policy" "staging_buckets" {
  name   = "skole-staging-buckets-policy"
  user   = aws_iam_user.backend_staging.name
  policy = data.aws_iam_policy_document.staging_buckets.json
}

resource "aws_iam_user_policy_attachment" "infra_admin" {
  user       = aws_iam_user.infra.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_user_policy_attachment" "monorepo_ec2" {
  user       = aws_iam_user.monorepo.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_iam_user_policy_attachment" "monorepo_ecs" {
  user       = aws_iam_user.monorepo.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}

resource "aws_iam_user_policy_attachment" "prod_send_ses" {
  user       = aws_iam_user.backend_prod.name
  policy_arn = aws_iam_policy.send_ses.arn
}

resource "aws_iam_user_policy_attachment" "staging_send_ses" {
  user       = aws_iam_user.backend_staging.name
  policy_arn = aws_iam_policy.send_ses.arn
}

resource "aws_iam_role" "ecs_instance" {
  name               = "skole-ecs-instance-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ecs_instance.json
}

resource "aws_iam_role" "ecs_execution" {
  name               = "skole-ecs-execution-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ecs_execution.json
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "ecs-instance-profile"
  path = "/"
  role = aws_iam_role.ecs_instance.id

  provisioner "local-exec" {
    # https://github.com/hashicorp/terraform/issues/2349#issuecomment-114168159
    command = "sleep 10"
  }
}

data "aws_iam_policy_document" "send_ses" {
  statement {
    effect    = "Allow"
    actions   = ["ses:SendRawEmail"]
    resources = [aws_ses_domain_identity.skoleapp_com.arn]
  }
}

data "aws_iam_policy_document" "prod_buckets" {
  # Reference from:
  # https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_examples_s3_rw-bucket.html
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.prod_media.arn, aws_s3_bucket.prod_static.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:*Object"]
    resources = ["${aws_s3_bucket.prod_media.arn}/*", "${aws_s3_bucket.prod_static.arn}/*"]
  }
}

data "aws_iam_policy_document" "staging_buckets" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.staging_media.arn, aws_s3_bucket.staging_static.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:*Object"]
    resources = ["${aws_s3_bucket.staging_media.arn}/*", "${aws_s3_bucket.staging_static.arn}/*"]
  }
}

data "aws_iam_policy_document" "ecs_instance" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_execution" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
