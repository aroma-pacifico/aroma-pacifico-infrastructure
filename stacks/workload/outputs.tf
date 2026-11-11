# Minimal outputs for the stacks and modules that build on the workload
# (PC-IAC-019 section 3.2): telemetry ingestion (B09b), the security stack
# (B06b) and observability.

output "dead_letter_queue_names" {
  description = "Dead-letter queue name of each inference function, for the alarms on the first message."
  value       = module.inference_functions.dead_letter_queue_names
}

output "inference_function_names" {
  description = "Lambda function name of each inference function, keyed by function key."
  value       = module.inference_functions.function_names
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

output "threshold_queue_url" {
  description = "Queue URL of the threshold function, the threshold_queue_url input of modules/telemetry-ingestion (B09b)."
  value       = module.inference_functions.queue_urls["thresh"]
}
