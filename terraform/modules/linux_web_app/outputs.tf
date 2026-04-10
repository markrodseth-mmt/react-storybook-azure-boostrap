output "id" {
  description = "App Service resource ID"
  value       = azurerm_linux_web_app.this.id
}

output "hostname" {
  description = "Default hostname (e.g. app-prefix-name-abc123.azurewebsites.net)"
  value       = azurerm_linux_web_app.this.default_hostname
}

output "identity_principal_id" {
  description = "System-assigned managed identity principal ID"
  value       = azurerm_linux_web_app.this.identity[0].principal_id
}
