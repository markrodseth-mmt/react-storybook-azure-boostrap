output "front_door_endpoint" {
  description = "Azure Front Door endpoint hostname"
  value       = module.front_door.endpoint_hostname
}

output "frontend_app_url" {
  description = "Frontend App Service URL"
  value       = "https://${module.frontend.hostname}"
}

output "backend_api_url" {
  description = "Backend API App Service URL"
  value       = "https://${module.backend.hostname}"
}

output "nginx_app_url" {
  description = "NGINX App Service URL"
  value       = "https://${module.nginx.hostname}"
}

output "container_registry_login_server" {
  description = "ACR login server"
  value       = module.container_registry.login_server
}

output "search_endpoint" {
  description = "Azure AI Search endpoint"
  value       = module.search.endpoint
}

output "vnet_id" {
  description = "VNet resource ID"
  value       = module.networking.vnet_id
}

output "resource_group_main" {
  description = "Main resource group name"
  value       = azurerm_resource_group.main.name
}

output "front_door_id" {
  description = "Azure Front Door instance GUID"
  value       = azurerm_cdn_frontdoor_profile.main.resource_guid
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = module.key_vault.uri
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace resource ID"
  value       = module.monitoring.log_analytics_workspace_id
}
