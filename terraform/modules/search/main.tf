resource "azurerm_search_service" "main" {
  name                          = "srch-${var.prefix}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = var.sku
  public_network_access_enabled = false
  local_authentication_enabled  = true
  authentication_failure_mode   = "http403"
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_private_endpoint" "search" {
  name                = "pe-${var.prefix}-search"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-search"
    private_connection_resource_id = azurerm_search_service.main.id
    subresource_names              = ["searchService"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-group-search"
    private_dns_zone_ids = var.private_dns_zone_ids
  }
}
