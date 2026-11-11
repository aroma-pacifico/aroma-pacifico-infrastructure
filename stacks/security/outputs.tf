# Minimal outputs for the stacks that build on security (PC-IAC-019 section 3.2):
# telemetry ingestion (B09b) and the function stack (B10). The firewall rules (B07b)
# are wired in this stack, so their outputs are listed further down.

output "cognito_group_names" {
  description = "Cognito group name of each role, keyed by role."
  value       = module.security.cognito_group_names
}

output "field_user_pool_arn" {
  description = "ARN of the field user pool (farmer, transporter, buyer), for API authorizers."
  value       = module.security.field_user_pool_arn
}

output "field_user_pool_id" {
  description = "ID of the field user pool."
  value       = module.security.field_user_pool_id
}

output "iot_logging_role_arn" {
  description = "ARN of the role that AWS IoT Core assumes to write its logs, for the logging_role_arn input of telemetry ingestion (B09b)."
  value       = module.security.iot_logging_role_arn
}

output "iot_rule_role_arn" {
  description = "ARN of the role that the telemetry topic rule assumes, for the rule_role_arn input of telemetry ingestion (B09b)."
  value       = module.security.iot_rule_role_arn
}

output "kms_key_arns" {
  description = "ARN of each customer-managed key, keyed by data class. B09b takes telemetry and logs, B10 and B13 take records, objects and logs."
  value       = module.security.kms_key_arns
}

output "revocation_role_arn" {
  description = "ARN of the role of the revocation function, for the function that revokes device and user identities."
  value       = module.security.revocation_role_arn
}

output "revocation_role_name" {
  description = "Name of the revocation role, for attaching the basic execution policy of the function."
  value       = module.security.revocation_role_name
}

output "secure_transport_policy_statements_json" {
  description = "Bucket policy with the deny statements for plain HTTP and TLS below 1.2, or null when no bucket is protected. Each bucket owner merges it into its bucket policy."
  value       = module.security.secure_transport_policy_statements_json
}

output "staff_user_pool_arn" {
  description = "ARN of the staff user pool (MFA required), for API authorizers."
  value       = module.security.staff_user_pool_arn
}

output "staff_user_pool_id" {
  description = "ID of the staff user pool."
  value       = module.security.staff_user_pool_id
}

# Firewall rules (B07b). The attachments belong to other stacks: the web ACLs go
# to the CloudFront distribution and the API front door, the groups to the data
# store and the Resolver inbound endpoint.

output "prefix_list_ids" {
  description = "IDs of the five collection center prefix lists, keyed cc_device_mgmt, cc_firewalls, cc_ground_stations, cc_logistics and cc_staff, for security group rules of other stacks."
  value       = module.firewall_rules.prefix_list_ids
}

output "rule_catalog" {
  description = "Every firewall rule created, keyed by policy table ID, with group, mechanism, validity (permanent or temporary) and the pre-production audit flag (PD-125), as input to the release notes and the audit."
  value       = module.firewall_rules.rule_catalog
}

output "security_group_ids" {
  description = "Security group IDs keyed session_host, resolver and data_store, for the host, the Resolver inbound endpoint and the data store to attach. No load_balancer key exists because the lookup front door has no load balancer (PD-051)."
  value       = module.firewall_rules.security_group_ids
}

output "temporary_rule_ids" {
  description = "IDs of the temporary security group rules; empty because temporary rules are added and removed as production changes (ASM-128)."
  value       = module.firewall_rules.temporary_rule_ids
}

output "web_acl_arns" {
  description = "ARNs of the web ACLs, keyed lookup and api, for the CloudFront distribution of the public lookup and the application API front door to associate."
  value       = module.firewall_rules.web_acl_arns
}

output "web_acl_settings" {
  description = "Scope, rate limits and allowed paths passed to the web ACLs (ASM-129, ASM-155, ASM-300), so the pre-production audit and the plan review read the thresholds in force."
  value = {
    api = {
      rate_limit_per_5_minutes = local.api_rate_limit
      scope                    = local.waf_scope
    }
    lookup = {
      allowed_path_prefixes    = local.lookup_allowed_path_prefixes
      rate_limit_per_5_minutes = local.lookup_rate_limit
      rate_scope_path          = local.lookup_rate_scope_path
      scope                    = local.waf_scope
    }
  }
}
