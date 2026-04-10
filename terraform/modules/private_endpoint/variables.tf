variable "prefix" {
  type        = string
  description = "Resource name prefix (project-environment)"
}

variable "name" {
  type        = string
  description = "Short name for this endpoint (e.g. redis, acr, frontend)"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group to deploy into"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for the private endpoint NIC"
}

variable "resource_id" {
  type        = string
  description = "Azure resource ID to connect to via Private Link"
}

variable "subresource_names" {
  type        = list(string)
  description = "Sub-resource type (e.g. [\"sites\"], [\"registry\"], [\"redisCache\"])"
}

variable "private_dns_zone_ids" {
  type        = list(string)
  description = "Private DNS zone IDs for automatic A-record registration"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the private endpoint"
}
