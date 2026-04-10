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

# ─── Private Endpoint ─────────────────────────────────────────────────────────

module "private_endpoint" {
  source = "../private_endpoint"

  prefix               = var.prefix
  name                 = "search"
  location             = var.location
  resource_group_name  = var.resource_group_name
  subnet_id            = var.private_endpoint_subnet_id
  resource_id          = azurerm_search_service.main.id
  subresource_names    = ["searchService"]
  private_dns_zone_ids = var.private_dns_zone_ids
  tags                 = var.tags
}
