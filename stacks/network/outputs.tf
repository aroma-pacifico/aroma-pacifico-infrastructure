output "routing_references" {
  description = "Public references of the selected connection for B07; no route is managed here."
  value = {
    customer_gateway_id = module.association.customer_gateway_id
    prefix_list_id      = module.association.center_prefix_list_id
    vpc_attachment_id   = module.association.vpc_attachment_id
    vpn_attachment_id   = module.association.vpn_attachment_id
    vpn_connection_id   = module.association.vpn_connection_id
  }
}

output "selected_center" {
  description = "Validated single-center configuration (key, department, approved /16 and environment)."
  value       = local.selected_center
}
