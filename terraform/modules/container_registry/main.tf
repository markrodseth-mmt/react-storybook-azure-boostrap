resource "azurerm_container_registry" "main" {
  name                          = "acr${replace(var.prefix, "-", "")}${var.suffix}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = var.sku
  admin_enabled                 = false
  public_network_access_enabled = false
  zone_redundancy_enabled       = var.sku == "Premium" ? true : false
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }

  dynamic "georeplications" {
    for_each = var.sku == "Premium" && var.replication_location != var.location ? [1] : []
    content {
      location                  = var.replication_location
      zone_redundancy_enabled   = false
      regional_endpoint_enabled = true
      tags                      = var.tags
    }
  }
}

# ─── Private Endpoint ─────────────────────────────────────────────────────────

resource "azurerm_private_endpoint" "acr" {
  name                = "pe-${var.prefix}-acr"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-acr"
    private_connection_resource_id = azurerm_container_registry.main.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-group-acr"
    private_dns_zone_ids = var.private_dns_zone_ids
  }
}
