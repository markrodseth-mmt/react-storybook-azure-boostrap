variable "prefix" { type = string }
variable "suffix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "sku" { type = string; default = "Premium" }
variable "replication_location" { type = string; default = "ukwest" }
variable "private_endpoint_subnet_id" { type = string }
variable "private_dns_zone_ids" { type = list(string) }
variable "tags" { type = map(string) }
