variable "prefix" { type = string }
variable "suffix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "vnet_integration_subnet_id" { type = string }
variable "private_endpoint_subnet_id" { type = string }
variable "acr_login_server" { type = string }
variable "acr_id" { type = string }
variable "search_endpoint" { type = string }
variable "search_key" { type = string; sensitive = true }
variable "redis_connection_string" { type = string; sensitive = true }
variable "private_dns_zone_ids" { type = list(string) }
variable "storage_blob_private_dns_zone_ids" { type = list(string) }
variable "storage_queue_private_dns_zone_ids" { type = list(string) }
variable "storage_table_private_dns_zone_ids" { type = list(string) }
variable "storage_file_private_dns_zone_ids" { type = list(string) }
variable "key_vault_id" {
  type        = string
  description = "Key Vault resource ID for secret references"
}
variable "key_vault_uri" {
  type        = string
  description = "Key Vault URI for @Microsoft.KeyVault references"
}
variable "tags" { type = map(string) }
