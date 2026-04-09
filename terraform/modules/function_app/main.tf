# ─── Storage Account (required by Function App) ───────────────────────────────

resource "azurerm_storage_account" "func" {
  name                            = "st${replace(var.prefix, "-", "")}fn${var.suffix}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  tags                            = var.tags
}

# ─── App Service Plan (Elastic Premium for VNet integration) ──────────────────

resource "azurerm_service_plan" "func" {
  name                = "asp-${var.prefix}-func"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "EP1"
  tags                = var.tags
}

# ─── Function App ─────────────────────────────────────────────────────────────

resource "azurerm_linux_function_app" "data_sync" {
  name                          = "func-${var.prefix}-datasync-${var.suffix}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  service_plan_id               = azurerm_service_plan.func.id
  storage_account_name          = azurerm_storage_account.func.name
  storage_account_access_key    = azurerm_storage_account.func.primary_access_key
  virtual_network_subnet_id     = var.vnet_integration_subnet_id
  public_network_access_enabled = false
  https_only                    = true
  tags                          = var.tags

  site_config {
    always_on              = true
    vnet_route_all_enabled = true

    application_stack {
      docker {
        image_name        = "data-sync:latest"
        image_tag         = "latest"
        registry_url      = "https://${var.acr_login_server}"
        registry_username = null # Managed identity
        registry_password = null
      }
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    DOCKER_REGISTRY_SERVER_URL          = "https://${var.acr_login_server}"
    WEBSITE_PULL_IMAGE_OVER_VNET        = "true"
    FUNCTIONS_WORKER_RUNTIME            = "dotnet-isolated"
    AZURE_SEARCH_ENDPOINT               = var.search_endpoint
    AZURE_SEARCH_KEY                    = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/azure-search-key/)"
    REDIS_CONNECTION_STRING             = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/redis-connection-string/)"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
    AzureWebJobsDisableHomepage         = "true"
  }
}

# ─── ACR Pull Permission ──────────────────────────────────────────────────────

resource "azurerm_role_assignment" "func_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_function_app.data_sync.identity[0].principal_id
}

# ─── Storage Account Private Endpoint ─────────────────────────────────────────
# Required: storage has public_network_access_enabled = false, so the Function
# App runtime must reach it over Private Link.

resource "azurerm_private_endpoint" "func_storage" {
  name                = "pe-${var.prefix}-func-storage"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-func-storage"
    private_connection_resource_id = azurerm_storage_account.func.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-group-func-storage"
    private_dns_zone_ids = var.storage_blob_private_dns_zone_ids
  }
}

# ─── Private Endpoint ─────────────────────────────────────────────────────────

resource "azurerm_private_endpoint" "func" {
  name                = "pe-${var.prefix}-func"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-func"
    private_connection_resource_id = azurerm_linux_function_app.data_sync.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-group-func"
    private_dns_zone_ids = var.private_dns_zone_ids
  }
}

# ─── Storage Private Endpoints (queue, table, file) ──────────────────────────
# The Function App runtime requires access to all four storage subresources.
# Blob is handled above; queue, table, and file are added here.

resource "azurerm_private_endpoint" "func_storage_queue" {
  name                = "pe-${var.prefix}-func-storage-queue"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-func-storage-queue"
    private_connection_resource_id = azurerm_storage_account.func.id
    subresource_names              = ["queue"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-group-func-storage-queue"
    private_dns_zone_ids = var.storage_queue_private_dns_zone_ids
  }
}

resource "azurerm_private_endpoint" "func_storage_table" {
  name                = "pe-${var.prefix}-func-storage-table"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-func-storage-table"
    private_connection_resource_id = azurerm_storage_account.func.id
    subresource_names              = ["table"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-group-func-storage-table"
    private_dns_zone_ids = var.storage_table_private_dns_zone_ids
  }
}

resource "azurerm_private_endpoint" "func_storage_file" {
  name                = "pe-${var.prefix}-func-storage-file"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-func-storage-file"
    private_connection_resource_id = azurerm_storage_account.func.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-group-func-storage-file"
    private_dns_zone_ids = var.storage_file_private_dns_zone_ids
  }
}

# ─── Key Vault RBAC ──────────────────────────────────────────────────────────
# Grant the Function App identity read access to Key Vault secrets via RBAC.

resource "azurerm_role_assignment" "func_kv_secrets" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.data_sync.identity[0].principal_id
}
