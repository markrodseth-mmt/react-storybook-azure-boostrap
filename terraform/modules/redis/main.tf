resource "azurerm_redis_cache" "main" {
  name                          = "redis-${var.prefix}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  capacity                      = var.redis_sku.capacity
  family                        = var.redis_sku.family
  sku_name                      = var.redis_sku.name
  non_ssl_port_enabled          = false
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags

  redis_configuration {
    maxmemory_reserved    = 50
    maxmemory_delta       = 50
    maxmemory_policy      = "allkeys-lru"
    enable_authentication = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

# ─── Private Endpoint ─────────────────────────────────────────────────────────

module "private_endpoint" {
  source = "../private_endpoint"

  prefix               = var.prefix
  name                 = "redis"
  location             = var.location
  resource_group_name  = var.resource_group_name
  subnet_id            = var.private_endpoint_subnet_id
  resource_id          = azurerm_redis_cache.main.id
  subresource_names    = ["redisCache"]
  private_dns_zone_ids = var.private_dns_zone_ids
  tags                 = var.tags
}
