variable "prefix" {
  type        = string
  description = "Resource name prefix (project-environment)"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group to deploy into"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources"
}

variable "diagnostic_targets" {
  type = map(object({
    resource_id    = string
    log_categories = list(string)
  }))
  description = <<-EOT
    Map of resources to monitor. Each key becomes the diagnostic setting name suffix.
    Example:
      diagnostic_targets = {
        redis = {
          resource_id    = module.redis.id
          log_categories = ["ConnectedClientList"]
        }
      }
  EOT
}
