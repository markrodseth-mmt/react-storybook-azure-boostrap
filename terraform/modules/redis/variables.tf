variable "prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "redis_sku" {
  type = object({ name = string, family = string, capacity = number })
}
variable "private_endpoint_subnet_id" { type = string }
variable "private_dns_zone_ids" { type = list(string) }
variable "tags" { type = map(string) }
