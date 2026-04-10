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
  description = "Azure region"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group to deploy into"
}

variable "vnet_integration_subnet_id" {
  type        = string
  description = "Subnet ID for Function App VNet integration"
}

variable "private_endpoint_subnet_id" {
  type        = string
  description = "Subnet ID for private endpoints"
}

variable "acr_login_server" {
  type        = string
  description = "ACR login server FQDN"
}

variable "acr_id" {
  type        = string
  description = "ACR resource ID for AcrPull role assignment"
}

variable "search_endpoint" {
  type        = string
  description = "Azure AI Search endpoint URL"
}

variable "private_dns_zone_ids" {
  type        = list(string)
  description = "Private DNS zone IDs for the Function App private endpoint"
}

variable "storage_blob_private_dns_zone_ids" {
  type        = list(string)
  description = "Private DNS zone IDs for storage blob"
}

variable "storage_queue_private_dns_zone_ids" {
  type        = list(string)
  description = "Private DNS zone IDs for storage queue"
}

variable "storage_table_private_dns_zone_ids" {
  type        = list(string)
  description = "Private DNS zone IDs for storage table"
}

variable "storage_file_private_dns_zone_ids" {
  type        = list(string)
  description = "Private DNS zone IDs for storage file"
}

variable "key_vault_id" {
  type        = string
  description = "Key Vault resource ID for RBAC assignment"
}

variable "key_vault_uri" {
  type        = string
  description = "Key Vault URI for @Microsoft.KeyVault() app setting references"
}

variable "application_insights_connection_string" {
  type        = string
  description = "Application Insights connection string"
  sensitive   = true
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources"
}
