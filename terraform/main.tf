resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  prefix = "${var.project}-${var.environment}"
  suffix = random_string.suffix.result
  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  })
}

# ─── Current Identity (for Key Vault RBAC) ───────────────────────────────────

data "azurerm_client_config" "current" {}

# ─── Resource Groups ─────────────────────────────────────────────────────────

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.prefix}-main"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_resource_group" "networking" {
  name     = "rg-${local.prefix}-networking"
  location = var.location
  tags     = local.common_tags
}

# ─── Networking ──────────────────────────────────────────────────────────────

module "networking" {
  source = "./modules/networking"

  prefix              = local.prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.networking.name
  vnet_address_space  = var.vnet_address_space
  subnet_config       = var.subnet_config
  tags                = local.common_tags
}

# ─── Container Registry ──────────────────────────────────────────────────────

module "container_registry" {
  source = "./modules/container_registry"

  prefix                     = local.prefix
  suffix                     = local.suffix
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  sku                        = var.acr_sku
  replication_location       = var.acr_replication_location
  private_endpoint_subnet_id = module.networking.private_endpoint_subnet_id
  private_dns_zone_ids       = module.networking.acr_private_dns_zone_ids
  tags                       = local.common_tags
}

# ─── App Services ─────────────────────────────────────────────────────────────

module "app_services" {
  source = "./modules/app_services"

  prefix                     = local.prefix
  suffix                     = local.suffix
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  app_service_sku            = var.app_service_sku
  nginx_sku                  = var.nginx_app_service_sku
  vnet_integration_subnet_id = module.networking.app_services_subnet_id
  private_endpoint_subnet_id = module.networking.private_endpoint_subnet_id
  acr_login_server           = module.container_registry.login_server
  acr_id                     = module.container_registry.id
  private_dns_zone_ids       = module.networking.app_service_private_dns_zone_ids
  front_door_id              = azurerm_cdn_frontdoor_profile.main.resource_guid
  tags                       = local.common_tags
}

# ─── Redis ───────────────────────────────────────────────────────────────────

module "redis" {
  source = "./modules/redis"

  prefix                     = local.prefix
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  redis_sku                  = var.redis_sku
  private_endpoint_subnet_id = module.networking.private_endpoint_subnet_id
  private_dns_zone_ids       = module.networking.redis_private_dns_zone_ids
  tags                       = local.common_tags
}

# ─── Azure AI Search ─────────────────────────────────────────────────────────

module "search" {
  source = "./modules/search"

  prefix                     = local.prefix
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  sku                        = var.search_sku
  private_endpoint_subnet_id = module.networking.private_endpoint_subnet_id
  private_dns_zone_ids       = module.networking.search_private_dns_zone_ids
  tags                       = local.common_tags
}

# ─── Key Vault ────────────────────────────────────────────────────────────────

module "key_vault" {
  source = "./modules/key_vault"

  prefix                     = local.prefix
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = var.tenant_id
  private_endpoint_subnet_id = module.networking.private_endpoint_subnet_id
  private_dns_zone_ids       = module.networking.key_vault_private_dns_zone_ids
  tags                       = local.common_tags
}

# ─── Key Vault RBAC ──────────────────────────────────────────────────────────
# Grant the deploying identity permission to manage secrets in Key Vault.

resource "azurerm_role_assignment" "deployer_kv_admin" {
  scope                = module.key_vault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Store secrets in Key Vault for App Service / Function App Key Vault references

resource "azurerm_key_vault_secret" "search_key" {
  name         = "azure-search-key"
  value        = module.search.primary_key
  key_vault_id = module.key_vault.id

  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}

resource "azurerm_key_vault_secret" "redis_connection_string" {
  name         = "redis-connection-string"
  value        = module.redis.primary_connection_string
  key_vault_id = module.key_vault.id

  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}

# ─── Function App (Data Sync) ────────────────────────────────────────────────

module "function_app" {
  source = "./modules/function_app"

  prefix                             = local.prefix
  suffix                             = local.suffix
  location                           = var.location
  resource_group_name                = azurerm_resource_group.main.name
  vnet_integration_subnet_id         = module.networking.functions_subnet_id
  private_endpoint_subnet_id         = module.networking.private_endpoint_subnet_id
  acr_login_server                   = module.container_registry.login_server
  acr_id                             = module.container_registry.id
  search_endpoint                    = module.search.endpoint
  search_key                         = module.search.primary_key
  redis_connection_string            = module.redis.primary_connection_string
  private_dns_zone_ids               = module.networking.function_private_dns_zone_ids
  storage_blob_private_dns_zone_ids  = module.networking.storage_blob_private_dns_zone_ids
  storage_queue_private_dns_zone_ids = module.networking.storage_queue_private_dns_zone_ids
  storage_table_private_dns_zone_ids = module.networking.storage_table_private_dns_zone_ids
  storage_file_private_dns_zone_ids  = module.networking.storage_file_private_dns_zone_ids
  key_vault_id                       = module.key_vault.id
  key_vault_uri                      = module.key_vault.uri
  tags                               = local.common_tags
}

# ─── Azure Front Door Profile (created first to break dependency cycle) ───────
# The profile resource_guid is needed by App Service access restrictions,
# while the full Front Door module needs App Service hostnames for origins.

resource "azurerm_cdn_frontdoor_profile" "main" {
  name                = "afd-${local.prefix}"
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Premium_AzureFrontDoor"
  tags                = local.common_tags
}

# ─── Azure Front Door ─────────────────────────────────────────────────────────

module "front_door" {
  source = "./modules/front_door"

  prefix              = local.prefix
  resource_group_name = azurerm_resource_group.main.name
  waf_mode            = var.waf_mode
  custom_domains      = var.custom_domains

  front_door_profile_id = azurerm_cdn_frontdoor_profile.main.id

  nginx_origin_hostname    = module.app_services.nginx_hostname
  frontend_origin_hostname = module.app_services.frontend_hostname
  backend_origin_hostname  = module.app_services.backend_hostname

  legacy_site_hostname = var.legacy_site_hostname
  legacy_site_patterns = var.legacy_site_patterns

  tags = local.common_tags
}

# ─── Monitoring ───────────────────────────────────────────────────────────────

module "monitoring" {
  source = "./modules/monitoring"

  prefix                = local.prefix
  location              = var.location
  resource_group_name   = azurerm_resource_group.main.name
  front_door_profile_id = azurerm_cdn_frontdoor_profile.main.id
  redis_id              = module.redis.id
  search_id             = module.search.id
  key_vault_id          = module.key_vault.id
  tags                  = local.common_tags
}
