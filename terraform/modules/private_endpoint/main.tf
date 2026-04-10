# ─── Private Endpoint (Reusable Building Block) ─────────────────────────────
#
# Standardised private endpoint with DNS zone group registration.
# Used by every service module that needs Private Link connectivity.
#
# Usage:
#   module "private_endpoint" {
#     source            = "../private_endpoint"
#     prefix            = var.prefix
#     name              = "redis"
#     location          = var.location
#     resource_group_name = var.resource_group_name
#     subnet_id         = var.private_endpoint_subnet_id
#     resource_id       = azurerm_redis_cache.main.id
#     subresource_names = ["redisCache"]
#     private_dns_zone_ids = var.private_dns_zone_ids
#     tags              = var.tags
#   }

resource "azurerm_private_endpoint" "this" {
  name                = "pe-${var.prefix}-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.name}"
    private_connection_resource_id = var.resource_id
    subresource_names              = var.subresource_names
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-group-${var.name}"
    private_dns_zone_ids = var.private_dns_zone_ids
  }
}
