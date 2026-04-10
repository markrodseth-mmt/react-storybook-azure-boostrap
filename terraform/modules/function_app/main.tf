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
    DOCKER_REGISTRY_SERVER_URL            = "https://${var.acr_login_server}"
    WEBSITE_PULL_IMAGE_OVER_VNET          = "true"
    FUNCTIONS_WORKER_RUNTIME              = "dotnet-isolated"
    AZURE_SEARCH_ENDPOINT                 = var.search_endpoint
    AZURE_SEARCH_KEY                      = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/azure-search-key/)"
    REDIS_CONNECTION_STRING               = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/redis-connection-string/)"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE   = "false"
    AzureWebJobsDisableHomepage           = "true"
    APPLICATIONINSIGHTS_CONNECTION_STRING = var.application_insights_connection_string
  }
}

# ─── ACR Pull Permission ─────────────────────────────────────────────────────

resource "azurerm_role_assignment" "func_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_function_app.data_sync.identity[0].principal_id
}

# ─── Key Vault RBAC ──────────────────────────────────────────────────────────

resource "azurerm_role_assignment" "func_kv_secrets" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.data_sync.identity[0].principal_id
}

# ─── Private Endpoints ────────────────────────────────────────────────────────

module "pe_func" {
  source = "../private_endpoint"

  prefix               = var.prefix
  name                 = "func"
  location             = var.location
  resource_group_name  = var.resource_group_name
  subnet_id            = var.private_endpoint_subnet_id
  resource_id          = azurerm_linux_function_app.data_sync.id
  subresource_names    = ["sites"]
  private_dns_zone_ids = var.private_dns_zone_ids
  tags                 = var.tags
}

# Storage requires private endpoints for all four subresources (blob, queue, table, file).

locals {
  storage_pe_config = {
    blob  = var.storage_blob_private_dns_zone_ids
    queue = var.storage_queue_private_dns_zone_ids
    table = var.storage_table_private_dns_zone_ids
    file  = var.storage_file_private_dns_zone_ids
  }
}

module "pe_storage" {
  for_each = local.storage_pe_config
  source   = "../private_endpoint"

  prefix               = var.prefix
  name                 = "func-storage-${each.key}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  subnet_id            = var.private_endpoint_subnet_id
  resource_id          = azurerm_storage_account.func.id
  subresource_names    = [each.key]
  private_dns_zone_ids = each.value
  tags                 = var.tags
}
