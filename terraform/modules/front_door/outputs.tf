output "endpoint_hostname" {
  value = azurerm_cdn_frontdoor_endpoint.main.host_name
}

output "profile_id" {
  value = var.front_door_profile_id
}
