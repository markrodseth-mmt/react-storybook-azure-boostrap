output "id" {
  value = azurerm_linux_function_app.data_sync.id
}

output "hostname" {
  value = azurerm_linux_function_app.data_sync.default_hostname
}

output "identity_principal_id" {
  value = azurerm_linux_function_app.data_sync.identity[0].principal_id
}
