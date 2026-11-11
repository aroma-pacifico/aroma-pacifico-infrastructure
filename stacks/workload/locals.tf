# Governance injection and derived values (AGENTS.md section 5.2). No resource
# is defined in this stack: the reference modules own every resource.
locals {
  # Tags passed to the modules, aligned with the provider default_tags so that
  # the modules and the provider never disagree on Environment.
  common_tags = merge(var.common_tags, { Environment = var.environment })

  # PC-IAC-003 naming inputs, built as in stacks/network. The modules cap
  # name_prefix at 16 characters.
  client      = lower(var.common_tags["Client"])
  project     = lower(var.common_tags["Project"])
  name_prefix = "${local.client}-${local.project}-${var.environment}"

  # Retention of the function log groups; the observability design uses 365 days.
  log_retention_days = 365

  # The threshold function (box D10) reads from the telemetry domain (box D09).
  # Until B09b wires module.telemetry_ingestion, both references come from
  # var.telemetry_references; B09b replaces them with the module outputs here.
  telemetry_table_arn = var.telemetry_references.table_arn
  telemetry_rule_arn  = var.telemetry_references.topic_rule_arn

  # The three drone functions share one shape (ASM-161, ASM-162) and differ in
  # their package and description. Sizing and retry values are the module
  # defaults of ASM-281.
  drone_function = {
    inference = { model_id = var.inference_model_id }
    read = {
      s3_object_arns      = [var.inference_targets.drone_object_arn_pattern]
      dynamodb_table_arns = [var.inference_targets.mission_table_arn]
      kms_classes         = ["objects"]
    }
    write = {
      dynamodb_table_arns = [var.inference_targets.mission_table_arn]
      kms_classes         = ["records"]
    }
    queue_senders = {
      service_principals = ["events.amazonaws.com"]
      source_arns        = [var.inference_targets.drone_event_rule_arn_pattern]
    }
  }

  inference_functions = {
    confrm = merge(local.drone_function, {
      description = "Confirms a pest focus from the confirmation mission objects."
      package     = var.inference_function_packages["confrm"]
    })
    verify = merge(local.drone_function, {
      description = "Verifies that a fumigated focus can close."
      package     = var.inference_function_packages["verify"]
    })
    estim = merge(local.drone_function, {
      description = "Estimates the crop load from the estimation mission objects."
      package     = var.inference_function_packages["estim"]
    })
    # Threshold function values of ASM-162 and ASM-281 (60 s, 256 MB, batch of
    # 10, concurrency 10, 10 s backoff base). The topic rule sends each reading
    # to its queue (ASM-161).
    thresh = {
      description          = "Evaluates a telemetry batch and labels the plausibility of an alert opening."
      package              = var.inference_function_packages["thresh"]
      timeout_seconds      = 60
      memory_mb            = 256
      batch_size           = 10
      reserved_concurrency = 10
      backoff_base_seconds = 10
      inference            = { model_id = var.inference_model_id }
      read = {
        dynamodb_table_arns = [local.telemetry_table_arn, var.inference_targets.thresholds_table_arn]
        kms_classes         = ["telemetry"]
      }
      write = {
        dynamodb_table_arns = [var.inference_targets.alert_table_arn]
        sns_topic_arns      = [var.inference_targets.alert_topic_arn]
        kms_classes         = ["records"]
      }
      queue_senders = {
        service_principals = ["iot.amazonaws.com"]
        source_arns        = [local.telemetry_rule_arn]
      }
    }
  }
}
