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
  private_endpoint_subnet_id = module.networking.subnet_ids["private_endpoints"]
  private_dns_zone_ids       = module.networking.private_dns_zone_ids["acr"]
  tags                       = local.common_tags
}

# ─── Azure Front Door Profile ────────────────────────────────────────────────
# Created at root to break the dependency cycle between AFD and App Services.

resource "azurerm_cdn_frontdoor_profile" "main" {
  name                = "afd-${local.prefix}"
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Premium_AzureFrontDoor"
  tags                = local.common_tags
}

# ─── App Service Plans ────────────────────────────────────────────────────────

resource "azurerm_service_plan" "nginx" {
  name                = "asp-${local.prefix}-nginx"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = var.nginx_app_service_sku
  tags                = local.common_tags
}

resource "azurerm_service_plan" "apps" {
  name                = "asp-${local.prefix}-apps"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = var.app_service_sku
  tags                = local.common_tags
}

# ─── Web Apps (using standardised linux_web_app module) ───────────────────────
# Each app only specifies what makes it unique: name, image, plan, and any
# extra app settings. All security/networking/monitoring defaults are baked
# into the module.

module "nginx" {
  source = "./modules/linux_web_app"

  prefix                                 = local.prefix
  name                                   = "nginx"
  suffix                                 = local.suffix
  location                               = var.location
  resource_group_name                    = azurerm_resource_group.main.name
  service_plan_id                        = azurerm_service_plan.nginx.id
  docker_image                           = "nginx:latest"
  acr_login_server                       = module.container_registry.login_server
  acr_id                                 = module.container_registry.id
  vnet_integration_subnet_id             = module.networking.subnet_ids["app_services"]
  private_endpoint_subnet_id             = module.networking.subnet_ids["private_endpoints"]
  private_dns_zone_ids                   = module.networking.private_dns_zone_ids["app_service"]
  front_door_id                          = azurerm_cdn_frontdoor_profile.main.resource_guid
  application_insights_connection_string = module.monitoring.application_insights_connection_string
  tags                                   = local.common_tags
}

module "frontend" {
  source = "./modules/linux_web_app"

  prefix                                 = local.prefix
  name                                   = "frontend"
  suffix                                 = local.suffix
  location                               = var.location
  resource_group_name                    = azurerm_resource_group.main.name
  service_plan_id                        = azurerm_service_plan.apps.id
  docker_image                           = "frontend:latest"
  acr_login_server                       = module.container_registry.login_server
  acr_id                                 = module.container_registry.id
  vnet_integration_subnet_id             = module.networking.subnet_ids["app_services"]
  private_endpoint_subnet_id             = module.networking.subnet_ids["private_endpoints"]
  private_dns_zone_ids                   = module.networking.private_dns_zone_ids["app_service"]
  front_door_id                          = azurerm_cdn_frontdoor_profile.main.resource_guid
  application_insights_connection_string = module.monitoring.application_insights_connection_string
  tags                                   = local.common_tags

  extra_app_settings = {
    PORT = "8080"
    # Storyblok credentials managed out-of-band via: ./cli/infra secrets:set <env>
  }
}

module "backend" {
  source = "./modules/linux_web_app"

  prefix                                 = local.prefix
  name                                   = "backend"
  suffix                                 = local.suffix
  location                               = var.location
  resource_group_name                    = azurerm_resource_group.main.name
  service_plan_id                        = azurerm_service_plan.apps.id
  docker_image                           = "backend-api:latest"
  acr_login_server                       = module.container_registry.login_server
  acr_id                                 = module.container_registry.id
  vnet_integration_subnet_id             = module.networking.subnet_ids["app_services"]
  private_endpoint_subnet_id             = module.networking.subnet_ids["private_endpoints"]
  private_dns_zone_ids                   = module.networking.private_dns_zone_ids["app_service"]
  front_door_id                          = azurerm_cdn_frontdoor_profile.main.resource_guid
  application_insights_connection_string = module.monitoring.application_insights_connection_string
  tags                                   = local.common_tags

  extra_app_settings = {
    ASPNETCORE_ENVIRONMENT = "Production"
    # Redis and Search connection strings injected post-deploy via Key Vault references
  }
}

# ─── Redis ───────────────────────────────────────────────────────────────────

module "redis" {
  source = "./modules/redis"

  prefix                     = local.prefix
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  redis_sku                  = var.redis_sku
  private_endpoint_subnet_id = module.networking.subnet_ids["private_endpoints"]
  private_dns_zone_ids       = module.networking.private_dns_zone_ids["redis"]
  tags                       = local.common_tags
}

# ─── Azure AI Search ─────────────────────────────────────────────────────────

module "search" {
  source = "./modules/search"

  prefix                     = local.prefix
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  sku                        = var.search_sku
  private_endpoint_subnet_id = module.networking.subnet_ids["private_endpoints"]
  private_dns_zone_ids       = module.networking.private_dns_zone_ids["search"]
  tags                       = local.common_tags
}

# ─── Key Vault ────────────────────────────────────────────────────────────────

module "key_vault" {
  source = "./modules/key_vault"

  prefix                     = local.prefix
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = var.tenant_id
  private_endpoint_subnet_id = module.networking.subnet_ids["private_endpoints"]
  private_dns_zone_ids       = module.networking.private_dns_zone_ids["key_vault"]
  tags                       = local.common_tags
}

# ─── Key Vault RBAC ──────────────────────────────────────────────────────────
# Grant the deploying identity permission to manage secrets in Key Vault.

resource "azurerm_role_assignment" "deployer_kv_admin" {
  scope                = module.key_vault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "backend_kv_secrets" {
  scope                = module.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.backend.identity_principal_id
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

  prefix                                 = local.prefix
  suffix                                 = local.suffix
  location                               = var.location
  resource_group_name                    = azurerm_resource_group.main.name
  vnet_integration_subnet_id             = module.networking.subnet_ids["functions"]
  private_endpoint_subnet_id             = module.networking.subnet_ids["private_endpoints"]
  acr_login_server                       = module.container_registry.login_server
  acr_id                                 = module.container_registry.id
  search_endpoint                        = module.search.endpoint
  private_dns_zone_ids                   = module.networking.private_dns_zone_ids["function_app"]
  storage_blob_private_dns_zone_ids      = module.networking.private_dns_zone_ids["storage_blob"]
  storage_queue_private_dns_zone_ids     = module.networking.private_dns_zone_ids["storage_queue"]
  storage_table_private_dns_zone_ids     = module.networking.private_dns_zone_ids["storage_table"]
  storage_file_private_dns_zone_ids      = module.networking.private_dns_zone_ids["storage_file"]
  key_vault_id                           = module.key_vault.id
  key_vault_uri                          = module.key_vault.uri
  application_insights_connection_string = module.monitoring.application_insights_connection_string
  tags                                   = local.common_tags
}

# ─── Azure Front Door ─────────────────────────────────────────────────────────

module "front_door" {
  source = "./modules/front_door"

  prefix              = local.prefix
  resource_group_name = azurerm_resource_group.main.name
  waf_mode            = var.waf_mode
  custom_domains      = var.custom_domains

  front_door_profile_id = azurerm_cdn_frontdoor_profile.main.id

  nginx_origin_hostname    = module.nginx.hostname
  frontend_origin_hostname = module.frontend.hostname
  backend_origin_hostname  = module.backend.hostname

  legacy_site_hostname = var.legacy_site_hostname
  legacy_site_patterns = var.legacy_site_patterns

  tags = local.common_tags
}

# ─── Monitoring ───────────────────────────────────────────────────────────────

module "monitoring" {
  source = "./modules/monitoring"

  prefix              = local.prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  diagnostic_targets = {
    front-door = {
      resource_id    = azurerm_cdn_frontdoor_profile.main.id
      log_categories = ["FrontDoorAccessLog", "FrontDoorHealthProbeLog", "FrontDoorWebApplicationFirewallLog"]
    }
    redis = {
      resource_id    = module.redis.id
      log_categories = ["ConnectedClientList"]
    }
    search = {
      resource_id    = module.search.id
      log_categories = ["OperationLogs"]
    }
    key-vault = {
      resource_id    = module.key_vault.id
      log_categories = ["AuditEvent"]
    }
    nginx = {
      resource_id    = module.nginx.id
      log_categories = ["AppServiceHTTPLogs", "AppServiceConsoleLogs", "AppServiceAppLogs"]
    }
    frontend = {
      resource_id    = module.frontend.id
      log_categories = ["AppServiceHTTPLogs", "AppServiceConsoleLogs", "AppServiceAppLogs"]
    }
    backend = {
      resource_id    = module.backend.id
      log_categories = ["AppServiceHTTPLogs", "AppServiceConsoleLogs", "AppServiceAppLogs"]
    }
    function-app = {
      resource_id    = module.function_app.id
      log_categories = ["FunctionAppLogs"]
    }
  }
}
