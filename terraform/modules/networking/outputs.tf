output "vnet_id" {
  description = "Virtual Network resource ID"
  value       = azurerm_virtual_network.main.id
}

output "subnet_ids" {
  description = "Map of subnet name to subnet ID (e.g. subnet_ids[\"app_services\"])"
  value       = { for k, v in azurerm_subnet.subnets : k => v.id }
}

output "private_dns_zone_ids" {
  description = "Map of service name to private DNS zone ID list (e.g. private_dns_zone_ids[\"redis\"])"
  value       = { for k, v in local.private_dns_zones : k => [azurerm_private_dns_zone.zones[v].id] }
}
