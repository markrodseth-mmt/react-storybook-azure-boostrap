resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "main" {
  name                = "appi-${var.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = var.tags
}

# ─── Diagnostic Settings (DRY via for_each) ──────────────────────────────────
# Each entry in diagnostic_targets creates a diagnostic setting that ships
# the specified log categories + AllMetrics to the shared Log Analytics workspace.

module "diagnostics" {
  for_each = var.diagnostic_targets
  source   = "../diagnostic_setting"

  name                       = "diag-${each.key}"
  target_resource_id         = each.value.resource_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  log_categories             = each.value.log_categories
}
