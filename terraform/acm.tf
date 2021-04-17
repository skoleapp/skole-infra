resource "aws_acm_certificate" "skoleapp_com" {
  domain_name       = "skoleapp.com"
  validation_method = "DNS"

  subject_alternative_names = ["*.skoleapp.com"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "skole_fi" {
  domain_name       = "skole.fi"
  validation_method = "DNS"

  subject_alternative_names = ["*.skole.fi"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "skole_io" {
  domain_name       = "skole.io"
  validation_method = "DNS"

  subject_alternative_names = ["*.skole.io"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "skoleapp_com" {
  certificate_arn         = aws_acm_certificate.skoleapp_com.arn
  validation_record_fqdns = [aws_route53_record.skoleapp_com_cert.fqdn]
}

resource "aws_acm_certificate_validation" "skole_fi" {
  certificate_arn         = aws_acm_certificate.skole_fi.arn
  validation_record_fqdns = [aws_route53_record.skole_fi_cert.fqdn]
}

resource "aws_acm_certificate_validation" "skole_io" {
  certificate_arn         = aws_acm_certificate.skole_io.arn
  validation_record_fqdns = [aws_route53_record.skole_io_cert.fqdn]
}
