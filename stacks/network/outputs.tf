# Minimal outputs for the stacks that build on the network (PC-IAC-019 section 3.2):
# firewall rules (B07b), telemetry ingestion (B09b) and the security stack (B06b).

output "availability_zone_ids" {
  description = "Availability Zone ID behind each slot (az1 to az3)."
  value       = module.network.availability_zone_ids
}

output "endpoint_security_group_ids" {
  description = "Security group ID of the interface endpoints of each tier that hosts any."
  value       = module.network.endpoint_security_group_ids
}

output "gateway_endpoint_ids" {
  description = "Gateway endpoint IDs keyed by service (s3, dynamodb), for endpoint conditions in bucket and table policies."
  value       = module.network.gateway_endpoint_ids
}

output "interface_endpoint_ids" {
  description = "Interface endpoint IDs keyed by the short name given in interface_endpoints, for endpoint policies."
  value       = module.network.interface_endpoint_ids
}

output "network_acl_ids" {
  description = "Network ACL ID of each tier, for later associations."
  value       = module.network.network_acl_ids
}

output "route_table_ids" {
  description = "Route table ID of each tier, for later routes and associations."
  value       = module.network.route_table_ids
}

output "subnet_cidr_blocks" {
  description = "Subnet CIDR blocks keyed by tier and Availability Zone slot, for security group rules."
  value       = module.network.subnet_cidr_blocks
}

output "subnet_ids" {
  description = "Subnet IDs keyed by tier and Availability Zone slot, for later routes, endpoints and associations."
  value       = module.network.subnet_ids
}

output "transit_attachment_subnet_ids" {
  description = "Subnets of the transit tier, one per Availability Zone slot, for the transit gateway attachment of the network account."
  value       = module.network.transit_attachment_subnet_ids
}

output "vpc_cidr_block" {
  description = "Primary IPv4 CIDR block of the environment VPC."
  value       = module.network.vpc_cidr_block
}

output "vpc_id" {
  description = "ID of the environment VPC."
  value       = module.network.vpc_id
}
