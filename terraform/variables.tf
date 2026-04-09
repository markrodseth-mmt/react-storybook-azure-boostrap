variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID for deployment"
}

variable "tenant_id" {
  type        = string
  description = "Azure Tenant ID"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "location" {
  type        = string
  description = "Primary Azure region"
  default     = "uksouth"
}

variable "project" {
  type        = string
  description = "Project/client identifier (used in resource naming)"
  default     = "quadient"
}

variable "tags" {
  type        = map(string)
  description = "Common tags applied to all resources"
  default     = {}
}

# Networking
variable "vnet_address_space" {
  type        = list(string)
  description = "Address space for the VNet"
  default     = ["10.0.0.0/16"]
}

variable "subnet_config" {
  type = map(object({
    address_prefixes  = list(string)
    service_endpoints = optional(list(string), [])
  }))
  description = "Subnet configuration map"
  default = {
    app_services = { address_prefixes = ["10.0.1.0/24"] }
    private_endpoints = { address_prefixes = ["10.0.2.0/24"] }
    devops_agents = { address_prefixes = ["10.0.3.0/24"] }
    functions     = { address_prefixes = ["10.0.4.0/24"] }
  }
}

# App Services
variable "app_service_sku" {
  type        = string
  description = "App Service Plan SKU"
  default     = "P1v3"
}

variable "nginx_app_service_sku" {
  type        = string
  description = "App Service Plan SKU for NGINX (can be scaled separately)"
  default     = "P2v3"
}

# Container Registry
variable "acr_sku" {
  type        = string
  description = "Azure Container Registry SKU"
  default     = "Premium"
}

# Redis
variable "redis_sku" {
  type = object({
    name     = string
    family   = string
    capacity = number
  })
  default = {
    name     = "Standard"
    family   = "C"
    capacity = 1
  }
}

# Azure AI Search
variable "search_sku" {
  type        = string
  description = "Azure AI Search SKU"
  default     = "standard"
}

# Front Door
variable "waf_mode" {
  type        = string
  description = "WAF policy mode: Detection or Prevention"
  default     = "Prevention"
}

variable "custom_domains" {
  type        = list(string)
  description = "Custom domains to configure on Azure Front Door"
  default     = []
}

# Legacy site (old site reverse proxy)
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


# Container Registry
variable "acr_replication_location" {
  type        = string
  description = "Secondary Azure region for ACR geo-replication (Premium SKU only)"
  default     = "ukwest"
}
