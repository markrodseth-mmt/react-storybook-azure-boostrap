# ─── Diagnostic Setting (Reusable Building Block) ────────────────────────────
#
# Standardised diagnostic setting that ships logs and metrics to Log Analytics.
# Eliminates copy-paste across monitoring targets.
#
# Usage:
#   module "diag_redis" {
#     source                     = "../diagnostic_setting"
#     name                       = "diag-redis"
#     target_resource_id         = module.redis.id
#     log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
#     log_categories             = ["ConnectedClientList"]
#   }

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                       = var.name
  target_resource_id         = var.target_resource_id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = var.log_categories
    content {
      category = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = var.enable_metrics ? ["AllMetrics"] : []
    content {
      category = metric.value
    }
  }
}
