variable "prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tags" { type = map(string) }

variable "front_door_profile_id" {
  type        = string
  description = "Azure Front Door profile ID for diagnostic settings"
}

variable "redis_id" {
  type        = string
  description = "Redis Cache resource ID for diagnostic settings"
}

variable "search_id" {
  type        = string
  description = "Azure AI Search resource ID for diagnostic settings"
}

variable "key_vault_id" {
  type        = string
  description = "Key Vault resource ID for diagnostic settings"
}

variable "nginx_app_service_id" {
  type        = string
  description = "NGINX App Service resource ID for diagnostic settings"
}

variable "frontend_app_service_id" {
  type        = string
  description = "Frontend App Service resource ID for diagnostic settings"
}

variable "backend_app_service_id" {
  type        = string
  description = "Backend App Service resource ID for diagnostic settings"
}

variable "function_app_id" {
  type        = string
  description = "Function App resource ID for diagnostic settings"
}
