resource "aws_lb" "prod" {
  name               = "skole-prod-elb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.prod_elb.id]

  subnet_mapping {
    subnet_id = aws_subnet.prod_a.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.prod_b.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.prod_c.id
  }
}

resource "aws_lb" "staging" {
  name               = "skole-staging-elb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.staging_elb.id]

  subnet_mapping {
    subnet_id = aws_subnet.staging_a.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.staging_b.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.staging_c.id
  }
}

resource "aws_lb_listener" "prod_http" {
  load_balancer_arn = aws_lb.prod.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "prod_https" {
  load_balancer_arn = aws_lb.prod.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.skoleapp_com.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_prod.arn
  }

  depends_on = [aws_acm_certificate_validation.skoleapp_com]
}

resource "aws_lb_listener" "staging_https" {
  load_balancer_arn = aws_lb.staging.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.skoleapp_com.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_staging.arn
  }

  depends_on = [aws_acm_certificate_validation.skoleapp_com]
}

resource "aws_lb_listener_certificate" "skole_fi" {
  listener_arn    = aws_lb_listener.prod_https.arn
  certificate_arn = aws_acm_certificate.skole_fi.arn
  depends_on      = [aws_acm_certificate_validation.skole_fi]
}

resource "aws_lb_listener_certificate" "skole_io" {
  listener_arn    = aws_lb_listener.prod_https.arn
  certificate_arn = aws_acm_certificate.skole_io.arn
  depends_on      = [aws_acm_certificate_validation.skole_io]
}

resource "aws_lb_listener_rule" "prod_http_redirect" {
  listener_arn = aws_lb_listener.prod_http.arn
  priority     = 1

  action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
      host        = "www.skoleapp.com"
    }
  }

  condition {
    host_header {
      values = ["www.skole.fi", "skole.fi", "www.skole.io", "skole.io", "skoleapp.com"]
    }
  }
}

resource "aws_lb_listener_rule" "prod_https_redirect" {
  listener_arn = aws_lb_listener.prod_https.arn
  priority     = 1

  action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
      host        = "www.skoleapp.com"
    }
  }

  condition {
    host_header {
      values = ["www.skole.fi", "skole.fi", "www.skole.io", "skole.io", "skoleapp.com"]
    }
  }
}

resource "aws_lb_listener_rule" "backend_staging" {
  listener_arn = aws_lb_listener.staging_https.arn
  priority     = 2

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_staging.arn
  }

  condition {
    host_header {
      values = ["dev-api.*"]
    }
  }
}

resource "aws_lb_listener_rule" "backend_prod" {
  listener_arn = aws_lb_listener.prod_https.arn
  priority     = 3

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_prod.arn
  }

  condition {
    host_header {
      values = ["api.*"]
    }
  }
}

resource "aws_lb_target_group" "backend_prod" {
  name        = "backend-prod"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.prod.id
  depends_on  = [aws_lb.prod]

  health_check {
    interval = 60
    path     = "/healthz/"
    matcher  = "200"
  }
}

resource "aws_lb_target_group" "backend_staging" {
  name        = "backend-staging"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.staging.id
  depends_on  = [aws_lb.staging]

  health_check {
    interval = 60
    path     = "/healthz/"
    matcher  = "200"
  }
}

resource "aws_lb_target_group" "frontend_prod" {
  name        = "frontend-prod"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.prod.id
  depends_on  = [aws_lb.prod]

  health_check {
    interval = 60
    path     = "/"
    matcher  = "200"
  }
}

resource "aws_lb_target_group" "frontend_staging" {
  name        = "frontend-staging"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.staging.id
  depends_on  = [aws_lb.staging]

  health_check {
    interval = 60
    path     = "/"
    matcher  = "200"
  }
}
