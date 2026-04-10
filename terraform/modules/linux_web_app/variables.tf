variable "prefix" {
  type        = string
  description = "Resource name prefix (project-environment)"
}

variable "name" {
  type        = string
  description = "Short app name (e.g. frontend, backend, nginx) — used in resource naming"
}

variable "suffix" {
  type        = string
  description = "Random suffix for globally unique resource names"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group to deploy into"
}

variable "service_plan_id" {
  type        = string
  description = "App Service Plan ID to host this app"
}

variable "docker_image" {
  type        = string
  description = "Docker image name and tag (e.g. frontend:latest, backend-api:v1.2.3)"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._/-]*:[a-zA-Z0-9._-]+$", var.docker_image))
    error_message = "Docker image must be in name:tag format (e.g. frontend:latest)."
  }
}

variable "acr_login_server" {
  type        = string
  description = "ACR login server FQDN (e.g. myacr.azurecr.io)"
}

variable "acr_id" {
  type        = string
  description = "ACR resource ID — used for AcrPull role assignment"
}

variable "vnet_integration_subnet_id" {
  type        = string
  description = "Subnet ID for App Service VNet integration (outbound traffic)"
}

variable "private_endpoint_subnet_id" {
  type        = string
  description = "Subnet ID for the inbound private endpoint"
}

variable "private_dns_zone_ids" {
  type        = list(string)
  description = "Private DNS zone IDs for automatic A-record registration"
}

variable "front_door_id" {
  type        = string
  description = "Azure Front Door resource GUID — used in IP restriction header filter"
}

variable "application_insights_connection_string" {
  type        = string
  description = "Application Insights connection string for APM"
  sensitive   = true
}

variable "health_check_path" {
  type        = string
  description = "Health check endpoint path"
  default     = "/health"

  validation {
    condition     = startswith(var.health_check_path, "/")
    error_message = "Health check path must start with /."
  }
}

variable "extra_app_settings" {
  type        = map(string)
  description = "Additional app settings merged with the standard set"
  default     = {}
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources"
}
