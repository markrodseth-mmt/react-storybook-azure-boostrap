environment = "dev"
location    = "uksouth"
project     = "bootstrap"

# Replace with actual client subscription/tenant IDs
subscription_id = "00000000-0000-0000-0000-000000000000"
tenant_id       = "00000000-0000-0000-0000-000000000000"

vnet_address_space = ["10.0.0.0/16"]

subnet_config = {
  app_services = {
    address_prefixes = ["10.0.1.0/24"]
  }
  private_endpoints = {
    address_prefixes = ["10.0.2.0/24"]
  }
  devops_agents = {
    address_prefixes = ["10.0.3.0/24"]
  }
  functions = {
    address_prefixes = ["10.0.4.0/24"]
  }
}

# Scaled-down SKUs for dev
app_service_sku       = "P1v3"
nginx_app_service_sku = "P1v3"
acr_sku               = "Premium"

redis_sku = {
  name     = "Standard"
  family   = "C"
  capacity = 0
}

search_sku = "basic"

waf_mode       = "Detection" # Detection in dev, Prevention in prod
custom_domains = []

# Legacy site reverse proxy — leave empty to disable in dev
legacy_site_hostname = ""
legacy_site_patterns = []

# ACR geo-replication
acr_replication_location = "ukwest"

tags = {
  Owner      = "platform-team"
  CostCenter = "engineering"
  Client     = "bootstrap"
}
