# ─── App Service Plans ────────────────────────────────────────────────────────

resource "azurerm_service_plan" "nginx" {
  name                = "asp-${var.prefix}-nginx"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.nginx_sku
  tags                = var.tags
}

resource "azurerm_service_plan" "apps" {
  name                = "asp-${var.prefix}-apps"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.app_service_sku
  tags                = var.tags
}

# ─── NGINX App Service ────────────────────────────────────────────────────────
# Handles high-volume redirects and complex routing rules

resource "azurerm_linux_web_app" "nginx" {
  name                      = "app-${var.prefix}-nginx-${var.suffix}"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  service_plan_id           = azurerm_service_plan.nginx.id
  virtual_network_subnet_id = var.vnet_integration_subnet_id
  https_only                = true
  tags                      = var.tags

  site_config {
    always_on              = true
    vnet_route_all_enabled = true
    health_check_path      = "/health"

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
      docker_image_name        = "nginx:latest"
      docker_registry_url      = "https://${var.acr_login_server}"
      docker_registry_username = null # Uses managed identity
      docker_registry_password = null
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    DOCKER_REGISTRY_SERVER_URL            = "https://${var.acr_login_server}"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE   = "false"
    WEBSITE_PULL_IMAGE_OVER_VNET          = "true"
    APPLICATIONINSIGHTS_CONNECTION_STRING = var.application_insights_connection_string
  }
}

# ─── Frontend App Service (Astro + Storyblok) ────────────────────────────────

resource "azurerm_linux_web_app" "frontend" {
  name                      = "app-${var.prefix}-frontend-${var.suffix}"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  service_plan_id           = azurerm_service_plan.apps.id
  virtual_network_subnet_id = var.vnet_integration_subnet_id
  https_only                = true
  tags                      = var.tags

  site_config {
    always_on              = true
    vnet_route_all_enabled = true
    health_check_path      = "/health"

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
      docker_image_name        = "frontend:latest"
      docker_registry_url      = "https://${var.acr_login_server}"
      docker_registry_username = null
      docker_registry_password = null
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    DOCKER_REGISTRY_SERVER_URL            = "https://${var.acr_login_server}"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE   = "false"
    WEBSITE_PULL_IMAGE_OVER_VNET          = "true"
    PORT                                  = "8080"
    APPLICATIONINSIGHTS_CONNECTION_STRING = var.application_insights_connection_string
    # Storyblok credentials are managed out-of-band via: ./cli/infra secrets:set <env>
  }
}

# ─── Backend API App Service (.NET minimal API + Fusion Cache) ────────────────

resource "azurerm_linux_web_app" "backend" {
  name                      = "app-${var.prefix}-backend-${var.suffix}"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  service_plan_id           = azurerm_service_plan.apps.id
  virtual_network_subnet_id = var.vnet_integration_subnet_id
  https_only                = true
  tags                      = var.tags

  site_config {
    always_on              = true
    vnet_route_all_enabled = true
    health_check_path      = "/health"

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
      docker_image_name        = "backend-api:latest"
      docker_registry_url      = "https://${var.acr_login_server}"
      docker_registry_username = null
      docker_registry_password = null
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    DOCKER_REGISTRY_SERVER_URL            = "https://${var.acr_login_server}"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE   = "false"
    WEBSITE_PULL_IMAGE_OVER_VNET          = "true"
    ASPNETCORE_ENVIRONMENT                = "Production"
    APPLICATIONINSIGHTS_CONNECTION_STRING = var.application_insights_connection_string
    # Redis and Search connection strings injected post-deploy via Key Vault references
  }
}

# ─── ACR Pull Role Assignments ────────────────────────────────────────────────

resource "azurerm_role_assignment" "nginx_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.nginx.identity[0].principal_id
}

resource "azurerm_role_assignment" "frontend_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.frontend.identity[0].principal_id
}

resource "azurerm_role_assignment" "backend_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.backend.identity[0].principal_id
}

# ─── Private Endpoints ────────────────────────────────────────────────────────

resource "azurerm_private_endpoint" "frontend" {
  name                = "pe-${var.prefix}-frontend"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-frontend"
    private_connection_resource_id = azurerm_linux_web_app.frontend.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-group-frontend"
    private_dns_zone_ids = var.private_dns_zone_ids
  }
}

resource "azurerm_private_endpoint" "backend" {
  name                = "pe-${var.prefix}-backend"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-backend"
    private_connection_resource_id = azurerm_linux_web_app.backend.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-group-backend"
    private_dns_zone_ids = var.private_dns_zone_ids
  }
}

resource "azurerm_private_endpoint" "nginx" {
  name                = "pe-${var.prefix}-nginx"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-nginx"
    private_connection_resource_id = azurerm_linux_web_app.nginx.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-group-nginx"
    private_dns_zone_ids = var.private_dns_zone_ids
  }
}
