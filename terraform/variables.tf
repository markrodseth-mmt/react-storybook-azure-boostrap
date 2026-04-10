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

  validation {
    condition     = can(regex("^[a-z]+[a-z0-9]*$", var.location))
    error_message = "Location must be a valid Azure region identifier (e.g. uksouth, westeurope)."
  }
}

variable "project" {
  type        = string
  description = "Project/client identifier (used in resource naming)"
  default     = "bootstrap"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,18}[a-z0-9]$", var.project))
    error_message = "Project must be 3-20 lowercase alphanumeric characters or hyphens, starting with a letter."
  }
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
    app_services      = { address_prefixes = ["10.0.1.0/24"] }
    private_endpoints = { address_prefixes = ["10.0.2.0/24"] }
    devops_agents     = { address_prefixes = ["10.0.3.0/24"] }
    functions         = { address_prefixes = ["10.0.4.0/24"] }
  }
}

# App Services
variable "app_service_sku" {
  type        = string
  description = "App Service Plan SKU"
  default     = "P1v3"

  validation {
    condition     = can(regex("^(B[123]|S[123]|P[1-3]v[23]|I[1-3]v2|Y1|EP[1-3])$", var.app_service_sku))
    error_message = "App Service SKU must be a valid plan tier (e.g. B1, S1, P1v3, EP1)."
  }
}

variable "nginx_app_service_sku" {
  type        = string
  description = "App Service Plan SKU for NGINX (can be scaled separately)"
  default     = "P2v3"

  validation {
    condition     = can(regex("^(B[123]|S[123]|P[1-3]v[23]|I[1-3]v2|Y1|EP[1-3])$", var.nginx_app_service_sku))
    error_message = "NGINX App Service SKU must be a valid plan tier (e.g. B1, S1, P1v3, EP1)."
  }
}

# Container Registry
variable "acr_sku" {
  type        = string
  description = "Azure Container Registry SKU"
  default     = "Premium"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "ACR SKU must be Basic, Standard, or Premium."
  }
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

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.redis_sku.name)
    error_message = "Redis SKU name must be Basic, Standard, or Premium."
  }

  validation {
    condition     = contains(["C", "P"], var.redis_sku.family)
    error_message = "Redis SKU family must be C (Basic/Standard) or P (Premium)."
  }

  validation {
    condition     = var.redis_sku.capacity >= 0 && var.redis_sku.capacity <= 6
    error_message = "Redis capacity must be between 0 and 6."
  }
}

# Azure AI Search
variable "search_sku" {
  type        = string
  description = "Azure AI Search SKU"
  default     = "standard"

  validation {
    condition     = contains(["free", "basic", "standard", "standard2", "standard3", "storage_optimized_l1", "storage_optimized_l2"], var.search_sku)
    error_message = "Search SKU must be one of: free, basic, standard, standard2, standard3, storage_optimized_l1, storage_optimized_l2."
  }
}

# Front Door
variable "waf_mode" {
  type        = string
  description = "WAF policy mode: Detection or Prevention"
  default     = "Prevention"

  validation {
    condition     = contains(["Detection", "Prevention"], var.waf_mode)
    error_message = "WAF mode must be Detection or Prevention."
  }
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
