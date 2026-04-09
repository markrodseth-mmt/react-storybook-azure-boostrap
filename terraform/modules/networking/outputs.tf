output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "app_services_subnet_id" {
  value = azurerm_subnet.subnets["app_services"].id
}

output "private_endpoint_subnet_id" {
  value = azurerm_subnet.subnets["private_endpoints"].id
}

output "devops_agents_subnet_id" {
  value = azurerm_subnet.subnets["devops_agents"].id
}

output "functions_subnet_id" {
  value = azurerm_subnet.subnets["functions"].id
}

output "app_service_private_dns_zone_ids" {
  value = [azurerm_private_dns_zone.zones["privatelink.azurewebsites.net"].id]
}

output "acr_private_dns_zone_ids" {
  value = [azurerm_private_dns_zone.zones["privatelink.azurecr.io"].id]
}

output "redis_private_dns_zone_ids" {
  value = [azurerm_private_dns_zone.zones["privatelink.redis.cache.windows.net"].id]
}

output "search_private_dns_zone_ids" {
  value = [azurerm_private_dns_zone.zones["privatelink.search.windows.net"].id]
}

output "function_private_dns_zone_ids" {
  value = [azurerm_private_dns_zone.zones["privatelink.azurewebsites.net"].id]
}

output "storage_blob_private_dns_zone_ids" {
  value = [azurerm_private_dns_zone.zones["privatelink.blob.core.windows.net"].id]
}

output "storage_queue_private_dns_zone_ids" {
  value = [azurerm_private_dns_zone.zones["privatelink.queue.core.windows.net"].id]
}

output "storage_table_private_dns_zone_ids" {
  value = [azurerm_private_dns_zone.zones["privatelink.table.core.windows.net"].id]
}

output "storage_file_private_dns_zone_ids" {
  value = [azurerm_private_dns_zone.zones["privatelink.file.core.windows.net"].id]
}

output "key_vault_private_dns_zone_ids" {
  value = [azurerm_private_dns_zone.zones["privatelink.vaultcore.azure.net"].id]
}
