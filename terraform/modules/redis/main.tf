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

resource "azurerm_private_endpoint" "redis" {
  name                = "pe-${var.prefix}-redis"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-redis"
    private_connection_resource_id = azurerm_redis_cache.main.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-group-redis"
    private_dns_zone_ids = var.private_dns_zone_ids
  }
}
