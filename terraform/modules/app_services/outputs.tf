output "nginx_hostname" {
  value = azurerm_linux_web_app.nginx.default_hostname
}

output "frontend_hostname" {
  value = azurerm_linux_web_app.frontend.default_hostname
}

output "backend_hostname" {
  value = azurerm_linux_web_app.backend.default_hostname
}

output "frontend_identity_principal_id" {
  value = azurerm_linux_web_app.frontend.identity[0].principal_id
}

output "backend_identity_principal_id" {
  value = azurerm_linux_web_app.backend.identity[0].principal_id
}
