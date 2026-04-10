variable "name" {
  type        = string
  description = "Diagnostic setting name (e.g. diag-redis)"
}

variable "target_resource_id" {
  type        = string
  description = "Azure resource ID to attach diagnostics to"
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics Workspace ID to send logs/metrics to"
}

variable "log_categories" {
  type        = list(string)
  description = "Log categories to enable (e.g. [\"AppServiceHTTPLogs\", \"AppServiceAppLogs\"])"
}

variable "enable_metrics" {
  type        = bool
  description = "Whether to ship AllMetrics to Log Analytics"
  default     = true
}
