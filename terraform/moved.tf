# ─── State Migration ──────────────────────────────────────────────────────────
# Moved blocks for the app_services module refactor. These allow Terraform to
# recognise that resources were reorganised, not destroyed and recreated.
#
# The old monolithic module.app_services has been split into:
#   - Root-level azurerm_service_plan resources
#   - module.nginx, module.frontend, module.backend (linux_web_app building block)
#
# These blocks can be removed after all environments have been migrated
# (i.e. after a successful `terraform apply` in every environment).

# ─── Service Plans ───────────────────────────────────────────────────────────

moved {
  from = module.app_services.azurerm_service_plan.nginx
  to   = azurerm_service_plan.nginx
}

moved {
  from = module.app_services.azurerm_service_plan.apps
  to   = azurerm_service_plan.apps
}

# ─── NGINX App Service ──────────────────────────────────────────────────────

moved {
  from = module.app_services.azurerm_linux_web_app.nginx
  to   = module.nginx.azurerm_linux_web_app.this
}

moved {
  from = module.app_services.azurerm_role_assignment.nginx_acr_pull
  to   = module.nginx.azurerm_role_assignment.acr_pull
}

moved {
  from = module.app_services.azurerm_private_endpoint.nginx
  to   = module.nginx.module.private_endpoint.azurerm_private_endpoint.this
}

# ─── Frontend App Service ───────────────────────────────────────────────────

moved {
  from = module.app_services.azurerm_linux_web_app.frontend
  to   = module.frontend.azurerm_linux_web_app.this
}

moved {
  from = module.app_services.azurerm_role_assignment.frontend_acr_pull
  to   = module.frontend.azurerm_role_assignment.acr_pull
}

moved {
  from = module.app_services.azurerm_private_endpoint.frontend
  to   = module.frontend.module.private_endpoint.azurerm_private_endpoint.this
}

# ─── Backend App Service ────────────────────────────────────────────────────

moved {
  from = module.app_services.azurerm_linux_web_app.backend
  to   = module.backend.azurerm_linux_web_app.this
}

moved {
  from = module.app_services.azurerm_role_assignment.backend_acr_pull
  to   = module.backend.azurerm_role_assignment.acr_pull
}

moved {
  from = module.app_services.azurerm_private_endpoint.backend
  to   = module.backend.module.private_endpoint.azurerm_private_endpoint.this
}

# ─── Networking (old individual outputs → map-based for_each) ────────────────
# The networking module moved from individual azurerm_subnet resources to
# for_each-based azurerm_subnet.subnets["key"]. If subnets were originally
# defined as individual resources, add moved blocks here.
# Example (uncomment if applicable to your state):
#
# moved {
#   from = module.networking.azurerm_subnet.app_services
#   to   = module.networking.azurerm_subnet.subnets["app_services"]
# }

# ─── Service Module Private Endpoints (inline → building block) ──────────────

moved {
  from = module.redis.azurerm_private_endpoint.redis
  to   = module.redis.module.private_endpoint.azurerm_private_endpoint.this
}

moved {
  from = module.container_registry.azurerm_private_endpoint.acr
  to   = module.container_registry.module.private_endpoint.azurerm_private_endpoint.this
}

moved {
  from = module.search.azurerm_private_endpoint.search
  to   = module.search.module.private_endpoint.azurerm_private_endpoint.this
}

moved {
  from = module.key_vault.azurerm_private_endpoint.key_vault
  to   = module.key_vault.module.private_endpoint.azurerm_private_endpoint.this
}

# Function App private endpoints (inline → building block)

moved {
  from = module.function_app.azurerm_private_endpoint.func
  to   = module.function_app.module.pe_func.azurerm_private_endpoint.this
}

moved {
  from = module.function_app.azurerm_private_endpoint.func_storage
  to   = module.function_app.module.pe_storage["blob"].azurerm_private_endpoint.this
}

moved {
  from = module.function_app.azurerm_private_endpoint.func_storage_queue
  to   = module.function_app.module.pe_storage["queue"].azurerm_private_endpoint.this
}

moved {
  from = module.function_app.azurerm_private_endpoint.func_storage_table
  to   = module.function_app.module.pe_storage["table"].azurerm_private_endpoint.this
}

moved {
  from = module.function_app.azurerm_private_endpoint.func_storage_file
  to   = module.function_app.module.pe_storage["file"].azurerm_private_endpoint.this
}

# ─── Monitoring Diagnostic Settings (individual → for_each module) ───────────

moved {
  from = module.monitoring.azurerm_monitor_diagnostic_setting.front_door
  to   = module.monitoring.module.diagnostics["front-door"].azurerm_monitor_diagnostic_setting.this
}

moved {
  from = module.monitoring.azurerm_monitor_diagnostic_setting.redis
  to   = module.monitoring.module.diagnostics["redis"].azurerm_monitor_diagnostic_setting.this
}

moved {
  from = module.monitoring.azurerm_monitor_diagnostic_setting.search
  to   = module.monitoring.module.diagnostics["search"].azurerm_monitor_diagnostic_setting.this
}

moved {
  from = module.monitoring.azurerm_monitor_diagnostic_setting.key_vault
  to   = module.monitoring.module.diagnostics["key-vault"].azurerm_monitor_diagnostic_setting.this
}

moved {
  from = module.monitoring.azurerm_monitor_diagnostic_setting.nginx
  to   = module.monitoring.module.diagnostics["nginx"].azurerm_monitor_diagnostic_setting.this
}

moved {
  from = module.monitoring.azurerm_monitor_diagnostic_setting.frontend
  to   = module.monitoring.module.diagnostics["frontend"].azurerm_monitor_diagnostic_setting.this
}

moved {
  from = module.monitoring.azurerm_monitor_diagnostic_setting.backend
  to   = module.monitoring.module.diagnostics["backend"].azurerm_monitor_diagnostic_setting.this
}

moved {
  from = module.monitoring.azurerm_monitor_diagnostic_setting.function_app
  to   = module.monitoring.module.diagnostics["function-app"].azurerm_monitor_diagnostic_setting.this
}
