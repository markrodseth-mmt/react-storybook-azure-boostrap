# ─── Linux Web App (Standardised Module) ─────────────────────────────────────
#
# Opinionated App Service with production defaults baked in:
#   • HTTPS-only, TLS 1.2 minimum, FTPS disabled, always-on
#   • All traffic routed through VNet (vnet_route_all_enabled)
#   • Default-deny IP restrictions — only Azure Front Door allowed
#   • SCM/Kudu site locked down (scm_ip_restriction_default_action = Deny)
#   • ACR pull via System-Assigned Managed Identity (no passwords)
#   • Private Endpoint with automatic DNS registration
#   • Application Insights integration
#
# Callers only supply the app-specific bits (image name, extra settings).
#
# Usage:
#   module "frontend" {
#     source              = "./modules/linux_web_app"
#     prefix              = local.prefix
#     name                = "frontend"
#     suffix              = local.suffix
#     location            = var.location
#     resource_group_name = azurerm_resource_group.main.name
#     service_plan_id     = azurerm_service_plan.apps.id
#     docker_image        = "frontend:latest"
#     acr_login_server    = module.container_registry.login_server
#     acr_id              = module.container_registry.id
#     vnet_integration_subnet_id = module.networking.subnet_ids["app_services"]
#     private_endpoint_subnet_id = module.networking.subnet_ids["private_endpoints"]
#     private_dns_zone_ids       = module.networking.private_dns_zone_ids["app_service"]
#     front_door_id              = azurerm_cdn_frontdoor_profile.main.resource_guid
#     application_insights_connection_string = module.monitoring.application_insights_connection_string
#     extra_app_settings  = { PORT = "8080" }
#     tags                = local.common_tags
#   }

resource "azurerm_linux_web_app" "this" {
  name                      = "app-${var.prefix}-${var.name}-${var.suffix}"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  service_plan_id           = var.service_plan_id
  virtual_network_subnet_id = var.vnet_integration_subnet_id
  https_only                = true
  tags                      = var.tags

  site_config {
    always_on              = true
    vnet_route_all_enabled = true
    health_check_path      = var.health_check_path
    ftps_state             = "Disabled"
    minimum_tls_version    = "1.2"

    ip_restriction_default_action     = "Deny"
    scm_ip_restriction_default_action = "Deny"

    ip_restriction {
      service_tag = "AzureFrontDoor.Backend"
      name        = "AllowFrontDoorOnly"
      priority    = 100
      action      = "Allow"
      headers {
        x_azure_fdid = [var.front_door_id]
      }
    }

    application_stack {
      docker_image_name        = var.docker_image
      docker_registry_url      = "https://${var.acr_login_server}"
      docker_registry_username = null # Uses managed identity
      docker_registry_password = null
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = merge(
    {
      DOCKER_REGISTRY_SERVER_URL            = "https://${var.acr_login_server}"
      WEBSITES_ENABLE_APP_SERVICE_STORAGE   = "false"
      WEBSITE_PULL_IMAGE_OVER_VNET          = "true"
      APPLICATIONINSIGHTS_CONNECTION_STRING = var.application_insights_connection_string
    },
    var.extra_app_settings,
  )
}

# ─── ACR Pull Permission ─────────────────────────────────────────────────────

resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.this.identity[0].principal_id
}

# ─── Private Endpoint ─────────────────────────────────────────────────────────

module "private_endpoint" {
  source = "../private_endpoint"

  prefix               = var.prefix
  name                 = var.name
  location             = var.location
  resource_group_name  = var.resource_group_name
  subnet_id            = var.private_endpoint_subnet_id
  resource_id          = azurerm_linux_web_app.this.id
  subresource_names    = ["sites"]
  private_dns_zone_ids = var.private_dns_zone_ids
  tags                 = var.tags
}
