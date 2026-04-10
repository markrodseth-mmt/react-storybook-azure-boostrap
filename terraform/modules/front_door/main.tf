# ─── WAF Policy ───────────────────────────────────────────────────────────────

resource "azurerm_cdn_frontdoor_firewall_policy" "main" {
  name                              = "waf${replace(var.prefix, "-", "")}policy"
  resource_group_name               = var.resource_group_name
  sku_name                          = "Premium_AzureFrontDoor"
  enabled                           = true
  mode                              = var.waf_mode
  redirect_url                      = null
  custom_block_response_status_code = 403
  tags                              = var.tags

  managed_rule {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
    action  = "Block"
  }

  managed_rule {
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.1"
    action  = "Block"
  }
}

# ─── Endpoint ────────────────────────────────────────────────────────────────

resource "azurerm_cdn_frontdoor_endpoint" "main" {
  name                     = "fde-${var.prefix}"
  cdn_frontdoor_profile_id = var.front_door_profile_id
  enabled                  = true
  tags                     = var.tags
}

# ─── Origin Groups & Origins (DRY via for_each) ──────────────────────────────

locals {
  origins = {
    nginx    = { hostname = var.nginx_origin_hostname }
    frontend = { hostname = var.frontend_origin_hostname }
    backend  = { hostname = var.backend_origin_hostname }
  }
}

resource "azurerm_cdn_frontdoor_origin_group" "origins" {
  for_each                 = local.origins
  name                     = "og-${each.key}"
  cdn_frontdoor_profile_id = var.front_door_profile_id

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }

  health_probe {
    interval_in_seconds = 30
    path                = "/health"
    protocol            = "Https"
    request_type        = "HEAD"
  }
}

resource "azurerm_cdn_frontdoor_origin" "origins" {
  for_each                       = local.origins
  name                           = "origin-${each.key}"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.origins[each.key].id
  enabled                        = true
  host_name                      = each.value.hostname
  origin_host_header             = each.value.hostname
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
  https_port                     = 443
  http_port                      = 80
}

# ─── Legacy Site Origin (conditional) ────────────────────────────────────────

resource "azurerm_cdn_frontdoor_origin_group" "legacy" {
  count                    = var.legacy_site_hostname != "" ? 1 : 0
  name                     = "og-legacy"
  cdn_frontdoor_profile_id = var.front_door_profile_id

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }

  health_probe {
    interval_in_seconds = 60
    path                = "/"
    protocol            = "Https"
    request_type        = "HEAD"
  }
}

resource "azurerm_cdn_frontdoor_origin" "legacy" {
  count                          = var.legacy_site_hostname != "" ? 1 : 0
  name                           = "origin-legacy"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.legacy[0].id
  enabled                        = true
  host_name                      = var.legacy_site_hostname
  origin_host_header             = var.legacy_site_hostname
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
  https_port                     = 443
  http_port                      = 80
}

# ─── Rule Sets ────────────────────────────────────────────────────────────────

resource "azurerm_cdn_frontdoor_rule_set" "main" {
  name                     = "ruleset${replace(var.prefix, "-", "")}"
  cdn_frontdoor_profile_id = var.front_door_profile_id
}

# ─── Routes ───────────────────────────────────────────────────────────────────
# Order matters: more-specific patterns must be defined before the catch-all.

resource "azurerm_cdn_frontdoor_route" "legacy" {
  count                         = var.legacy_site_hostname != "" && length(var.legacy_site_patterns) > 0 ? 1 : 0
  name                          = "route-legacy"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.legacy[0].id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.legacy[0].id]
  enabled                       = true

  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  patterns_to_match      = var.legacy_site_patterns
  supported_protocols    = ["Http", "Https"]

  cdn_frontdoor_rule_set_ids = [azurerm_cdn_frontdoor_rule_set.main.id]
}

resource "azurerm_cdn_frontdoor_route" "api" {
  name                          = "route-api"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.origins["backend"].id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.origins["backend"].id]
  enabled                       = true

  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/api/*"]
  supported_protocols    = ["Http", "Https"]

  cdn_frontdoor_rule_set_ids = [azurerm_cdn_frontdoor_rule_set.main.id]
}

resource "azurerm_cdn_frontdoor_route" "nginx_redirects" {
  name                          = "route-nginx-redirects"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.origins["nginx"].id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.origins["nginx"].id]
  enabled                       = true

  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/r/*", "/redirect/*"]
  supported_protocols    = ["Http", "Https"]

  cdn_frontdoor_rule_set_ids = [azurerm_cdn_frontdoor_rule_set.main.id]
}

resource "azurerm_cdn_frontdoor_route" "frontend" {
  name                          = "route-frontend"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.origins["frontend"].id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.origins["frontend"].id]
  enabled                       = true

  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]

  cdn_frontdoor_custom_domain_ids = [for d in azurerm_cdn_frontdoor_custom_domain.domains : d.id]
  cdn_frontdoor_rule_set_ids      = [azurerm_cdn_frontdoor_rule_set.main.id]

  cache {
    query_string_caching_behavior = "IgnoreSpecifiedQueryStrings"
    compression_enabled           = true
    content_types_to_compress     = ["text/html", "text/css", "application/javascript"]
  }
}

# ─── Security Policy (WAF attachment) ────────────────────────────────────────

resource "azurerm_cdn_frontdoor_security_policy" "main" {
  name                     = "security-${var.prefix}"
  cdn_frontdoor_profile_id = var.front_door_profile_id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.main.id

      association {
        patterns_to_match = ["/*"]

        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.main.id
        }

        dynamic "domain" {
          for_each = azurerm_cdn_frontdoor_custom_domain.domains
          content {
            cdn_frontdoor_domain_id = domain.value.id
          }
        }
      }
    }
  }
}

# ─── Custom Domains ───────────────────────────────────────────────────────────

resource "azurerm_cdn_frontdoor_custom_domain" "domains" {
  for_each = toset(var.custom_domains)

  name                     = replace(each.value, ".", "-")
  cdn_frontdoor_profile_id = var.front_door_profile_id
  host_name                = each.value

  tls {
    certificate_type    = "ManagedCertificate"
    minimum_tls_version = "TLS12"
  }
}
