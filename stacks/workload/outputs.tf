# Minimal outputs for the stacks and modules that build on the workload
# (PC-IAC-019 section 3.2): the security stack (B06b), the firewall and
# observability stacks and node provisioning.

output "dead_letter_queue_names" {
  description = "Dead-letter queue name of each inference function, for the alarms on the first message."
  value       = module.inference_functions.dead_letter_queue_names
}

output "domain_configuration_name" {
  description = "Name of the IoT Core domain configuration that carries the TLS policy, for the audit of the TLS rows CL-TEL-01 and CL-TEL-02."
  value       = module.telemetry_ingestion.domain_configuration_name
}

output "error_queue_arn" {
  description = "ARN of the rule error queue of the telemetry topic rule, for the replay of failed readings."
  value       = module.telemetry_ingestion.error_queue_arn
}

output "error_queue_name" {
  description = "Name of the rule error queue, for the alarm on its first message."
  value       = module.telemetry_ingestion.error_queue_name
}

output "farm_certificate_arns" {
  description = "Certificate ARN of each node by farm key and node role, for the revocation process; no private key or PEM material."
  value       = { for key, farm in module.farm : key => farm.certificate_arns }
}

output "farm_node_names" {
  description = "Registry name and MQTT client identifier of each node by farm key and node role."
  value       = { for key, farm in module.farm : key => farm.node_names }
}

output "farm_telemetry_topics" {
  description = "Topic each node publishes to, by farm key and node role."
  value       = { for key, farm in module.farm : key => farm.telemetry_topics }
}

output "inference_function_names" {
  description = "Lambda function name of each inference function, keyed by function key."
  value       = module.inference_functions.function_names
}

output "iot_endpoint" {
  description = "Hostname of the IoT Core data endpoint that the nodes connect to over MQTT with TLS, for node provisioning."
  value       = module.telemetry_ingestion.endpoint
}

output "iot_log_group_name" {
  description = "Name of the IoT Core log group, for the metric filters and alarms on its ERROR entries."
  value       = module.telemetry_ingestion.log_group_name
}

output "key_user_arns" {
  description = "Inference function role ARNs by key class (telemetry, objects, records), for the key_user_arns input of the security module in stacks/security."
  value       = module.inference_functions.key_user_arns
}

output "queue_arns" {
  description = "Trigger queue ARN of each inference function, for the send permission of the telemetry rule role and the drone event rules."
  value       = module.inference_functions.queue_arns
}

output "queue_urls" {
  description = "Trigger queue URL of each inference function, keyed by function key."
  value       = module.inference_functions.queue_urls
}

output "telemetry_table_arn" {
  description = "ARN of the telemetry table, for the read permission of the dashboards and the daily summaries."
  value       = module.telemetry_ingestion.telemetry_table_arn
}

output "telemetry_table_name" {
  description = "Name of the telemetry table."
  value       = module.telemetry_ingestion.telemetry_table_name
}

output "threshold_queue_url" {
  description = "Queue URL of the threshold function, the threshold_queue_url input of modules/telemetry-ingestion."
  value       = module.inference_functions.queue_urls["thresh"]
}

output "topic_rule_arn" {
  description = "ARN of the telemetry topic rule, the only sender allowed on the threshold queue."
  value       = module.telemetry_ingestion.topic_rule_arn
}

output "topic_rule_name" {
  description = "Name of the telemetry topic rule, for its metrics and alarms."
  value       = module.telemetry_ingestion.topic_rule_name
}
