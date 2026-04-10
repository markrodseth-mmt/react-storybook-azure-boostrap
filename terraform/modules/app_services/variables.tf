variable "prefix" {
  type        = string
  description = "Resource name prefix (project-environment)"
}
variable "suffix" {
  type        = string
  description = "Random suffix for globally unique resource names"
}
variable "location" {
  type        = string
  description = "Azure region for resource deployment"
}
variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to deploy into"
}
variable "app_service_sku" {
  type        = string
  description = "SKU for the frontend/backend App Service Plan (e.g. P1v3, P2v3)"
}
variable "nginx_sku" {
  type        = string
  description = "SKU for the NGINX App Service Plan (scaled independently)"
}
variable "vnet_integration_subnet_id" {
  type        = string
  description = "Subnet ID for App Service VNet integration"
}
variable "private_endpoint_subnet_id" {
  type        = string
  description = "Subnet ID for private endpoints"
}
variable "acr_login_server" {
  type        = string
  description = "ACR login server FQDN (e.g. myacr.azurecr.io)"
}
variable "acr_id" {
  type        = string
  description = "ACR resource ID for AcrPull role assignment"
}
variable "private_dns_zone_ids" {
  type        = list(string)
  description = "Private DNS zone IDs for App Service private endpoints"
}
variable "front_door_id" {
  type        = string
  description = "Azure Front Door resource GUID for access restriction"
}
variable "application_insights_connection_string" {
  type        = string
  description = "Application Insights connection string for APM"
  sensitive   = true
}
variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources"
}
