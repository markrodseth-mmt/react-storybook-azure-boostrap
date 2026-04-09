variable "prefix" { type = string }
variable "resource_group_name" { type = string }
variable "waf_mode" { type = string }
variable "custom_domains" { type = list(string) }
variable "front_door_profile_id" {
  type        = string
  description = "ID of the Azure Front Door profile (created at root to break dependency cycle)"
}
variable "nginx_origin_hostname" { type = string }
variable "frontend_origin_hostname" { type = string }
variable "backend_origin_hostname" { type = string }
variable "tags" { type = map(string) }

variable "legacy_site_hostname" {
  type        = string
  description = "FQDN of the old externally-hosted site for reverse proxy migration"
  default     = ""
}

variable "legacy_site_patterns" {
  type        = list(string)
  description = "URL patterns to route to the legacy site (e.g. /legacy/*)"
  default     = []
}
