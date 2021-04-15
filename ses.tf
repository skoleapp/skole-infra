resource "aws_ses_domain_identity" "skoleapp_com" {
  domain = "skoleapp.com"
}

resource "aws_ses_domain_dkim" "skoleapp_com" {
  domain = aws_ses_domain_identity.skoleapp_com.domain
}

resource "aws_ses_configuration_set" "this" {
  name = "skole-ses-config"
}

resource "aws_ses_event_destination" "this" {
  name                   = "skole-ses-destination"
  configuration_set_name = aws_ses_configuration_set.this.name
  matching_types         = ["bounce", "complaint", "reject"]
  enabled                = true

  cloudwatch_destination {
    default_value  = "default"
    dimension_name = "dimension"
    value_source   = "emailHeader"
  }
}
