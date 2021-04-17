resource "aws_route53_zone" "skoleapp_com" {
  name              = "skoleapp.com"
  delegation_set_id = aws_route53_delegation_set.this.id

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_zone" "skole_fi" {
  name              = "skole.fi"
  delegation_set_id = aws_route53_delegation_set.this.id

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_zone" "skole_io" {
  name              = "skole.io"
  delegation_set_id = aws_route53_delegation_set.this.id

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_delegation_set" "this" {
  reference_name = "skole-dns"
}

resource "aws_route53_record" "skoleapp_com_cert" {
  name    = tolist(aws_acm_certificate.skoleapp_com.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.skoleapp_com.domain_validation_options)[0].resource_record_type
  zone_id = aws_route53_zone.skoleapp_com.zone_id
  records = [tolist(aws_acm_certificate.skoleapp_com.domain_validation_options)[0].resource_record_value]
  ttl     = "60"
}

resource "aws_route53_record" "skole_fi_cert" {
  name    = tolist(aws_acm_certificate.skole_fi.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.skole_fi.domain_validation_options)[0].resource_record_type
  zone_id = aws_route53_zone.skole_fi.zone_id
  records = [tolist(aws_acm_certificate.skole_fi.domain_validation_options)[0].resource_record_value]
  ttl     = "60"
}

resource "aws_route53_record" "skole_io_cert" {
  name    = tolist(aws_acm_certificate.skole_io.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.skole_io.domain_validation_options)[0].resource_record_type
  zone_id = aws_route53_zone.skole_io.zone_id
  records = [tolist(aws_acm_certificate.skole_io.domain_validation_options)[0].resource_record_value]
  ttl     = "60"
}

resource "aws_route53_record" "www_skoleapp_com" {
  zone_id = aws_route53_zone.skoleapp_com.zone_id
  name    = "www.skoleapp.com"
  type    = "A"

  alias {
    name                   = aws_lb.prod.dns_name
    zone_id                = aws_lb.prod.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "skoleapp_com" {
  zone_id = aws_route53_zone.skoleapp_com.zone_id
  name    = "skoleapp.com"
  type    = "A"

  alias {
    name                   = aws_lb.prod.dns_name
    zone_id                = aws_lb.prod.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api_skoleapp_com" {
  zone_id = aws_route53_zone.skoleapp_com.zone_id
  name    = "api.skoleapp.com"
  type    = "A"

  alias {
    name                   = aws_lb.prod.dns_name
    zone_id                = aws_lb.prod.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "dev_skoleapp_com" {
  zone_id = aws_route53_zone.skoleapp_com.zone_id
  name    = "dev.skoleapp.com"
  type    = "A"

  alias {
    name                   = aws_lb.staging.dns_name
    zone_id                = aws_lb.staging.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "dev_api_skoleapp_com" {
  zone_id = aws_route53_zone.skoleapp_com.zone_id
  name    = "dev-api.skoleapp.com"
  type    = "A"

  alias {
    name                   = aws_lb.staging.dns_name
    zone_id                = aws_lb.staging.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www_skole_fi" {
  zone_id = aws_route53_zone.skole_fi.zone_id
  name    = "www.skole.fi"
  type    = "A"

  alias {
    name                   = aws_lb.prod.dns_name
    zone_id                = aws_lb.prod.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "skole_fi" {
  zone_id = aws_route53_zone.skole_fi.zone_id
  name    = "skole.fi"
  type    = "A"

  alias {
    name                   = aws_lb.prod.dns_name
    zone_id                = aws_lb.prod.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www_skole_io" {
  zone_id = aws_route53_zone.skole_io.zone_id
  name    = "www.skole.io"
  type    = "A"

  alias {
    name                   = aws_lb.prod.dns_name
    zone_id                = aws_lb.prod.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "skole_io" {
  zone_id = aws_route53_zone.skole_io.zone_id
  name    = "skole.io"
  type    = "A"

  alias {
    name                   = aws_lb.prod.dns_name
    zone_id                = aws_lb.prod.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "skoleapp_com_ses" {
  zone_id = aws_route53_record.skoleapp_com.zone_id
  name    = "_amazonses.skoleapp.com"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.skoleapp_com.verification_token]
}

resource "aws_route53_record" "example_amazonses_dkim_record" {
  count   = 3
  zone_id = aws_route53_record.skoleapp_com.zone_id
  name    = "${element(aws_ses_domain_dkim.skoleapp_com.dkim_tokens, count.index)}._domainkey.skoleapp.com"
  type    = "CNAME"
  ttl     = "600"
  records = ["${element(aws_ses_domain_dkim.skoleapp_com.dkim_tokens, count.index)}.dkim.amazonses.com"]
}

resource "aws_route53_record" "www_skoleapp_com_github_verification" {
  zone_id = aws_route53_record.skoleapp_com.zone_id
  name    = "_github-challenge-skoleapp.www.skoleapp.com."
  type    = "TXT"
  ttl     = 600
  records = ["9a964fcd61"]
}

resource "aws_route53_record" "skoleapp_com_github_verification" {
  zone_id = aws_route53_record.skoleapp_com.zone_id
  name    = "_github-challenge-skoleapp.skoleapp.com."
  type    = "TXT"
  ttl     = 600
  records = ["da6b2257fe"]
}

resource "aws_route53_record" "skoleapp_com_gmail_verification" {
  zone_id = aws_route53_record.skoleapp_com.zone_id
  name    = ""
  type    = "MX"
  ttl     = 300

  records = [
    "1 ASPMX.L.GOOGLE.COM.",
    "5 ALT1.ASPMX.L.GOOGLE.COM.",
    "5 ALT2.ASPMX.L.GOOGLE.COM.",
    "10 ALT3.ASPMX.L.GOOGLE.COM.",
    "10 ALT4.ASPMX.L.GOOGLE.COM.",
    "15 oaffzqqtrqvihc62qjong2pnj3at6f6q77yr36djmsubhashfe4a.mx-verification.google.com.",
  ]
}

resource "aws_route53_record" "skoleapp_com_gmail_dkim" {
  zone_id = aws_route53_record.skoleapp_com.zone_id
  name    = "google._domainkey"
  type    = "TXT"
  ttl     = 600
  records = ["v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA6Z7iPj+devxs0EB7hkaJGpyhAtzNJI1MU/u8V3UYuwliBHPvTV9GqOSi36ypIHfEbNhI2U7qMV0vx+noEWqYvWVwxsnqW2/GORC34lHbv4MYevlHDVBQcRPZ6VvroTw7vmziH+E1xm6jeDYvFn4o+S5l9f7EXVmjUwHuUz7vHX94MyhCgD+unDdKrsfRFuQYB\"\"ED0Os/dKTvkS8iBSjjDNXzh1lgHxfcgyESgapLX8w7dBgsfARjSocZCxDtmGY0QHfXcyTWMKuz432PWdfpquFb79VxGOXxuSr25z04YL5zEOyKXY99qRtmDBiVWLLLZd/AIN/uSQqz7ufc3MiSWPwIDAQAB"]
}

resource "aws_route53_record" "prod_simple_analytics" {
  zone_id = aws_route53_record.skoleapp_com.zone_id
  name    = "sa"
  type    = "CNAME"
  ttl     = "600"
  records = ["external.simpleanalytics.com."]
}

resource "aws_route53_record" "staging_simple_analytics" {
  zone_id = aws_route53_record.skoleapp_com.zone_id
  name    = "dev-sa"
  type    = "CNAME"
  ttl     = "600"
  records = ["external.simpleanalytics.com."]
}

resource "aws_route53_health_check" "skoleapp_com" {
  fqdn              = "skoleapp.com"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30
}

resource "aws_route53_health_check" "www_skoleapp_com" {
  fqdn              = "www.skoleapp.com"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30
}

resource "aws_route53_health_check" "skole_fi" {
  fqdn              = "skole.fi"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30
}

resource "aws_route53_health_check" "www_skole_fi" {
  fqdn              = "www.skole.fi"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30
}
