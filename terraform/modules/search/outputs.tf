output "id" {
  value = azurerm_search_service.main.id
}

output "endpoint" {
  value = "https://${azurerm_search_service.main.name}.search.windows.net"
}

output "primary_key" {
  value     = azurerm_search_service.main.primary_key
  sensitive = true
}

output "query_keys" {
  value     = azurerm_search_service.main.query_keys
  sensitive = true
}
