resource "azurerm_key_vault" "main" {
  name                          = "kv-${var.prefix}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  soft_delete_retention_days    = 90
  purge_protection_enabled      = true
  public_network_access_enabled = false
  enable_rbac_authorization     = true
  tags                          = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

# ─── Private Endpoint ─────────────────────────────────────────────────────────

module "private_endpoint" {
  source = "../private_endpoint"

  prefix               = var.prefix
  name                 = "kv"
  location             = var.location
  resource_group_name  = var.resource_group_name
  subnet_id            = var.private_endpoint_subnet_id
  resource_id          = azurerm_key_vault.main.id
  subresource_names    = ["vault"]
  private_dns_zone_ids = var.private_dns_zone_ids
  tags                 = var.tags
}
