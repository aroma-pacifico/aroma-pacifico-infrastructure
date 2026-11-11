# Plan-mode tests of the telemetry ingestion wiring of the workload stack
# (B09b, PC-IAC-018). Offline: the provider is mocked, so no credential,
# endpoint or account is involved. A test file reads only the outputs of a module
# call, never its resources, so the assertions check the values that this stack
# derives from the module outputs and feeds back to the other modules. The
# role pass-through into the topic rule and the IoT logging options is shown by
# the plan JSON in the pull request, not here.
mock_provider "aws" {
  override_during = plan

  mock_data "aws_caller_identity" {
    defaults = { account_id = "000000000000" }
  }

  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }

  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }

  # Attributes that AWS computes: the data endpoint host and the table ARN. The
  # mock returns synthetic values so that the contract can be asserted at plan.
  mock_resource "aws_iot_domain_configuration" {
    defaults = { domain_name = "ingestion.example.invalid" }
  }

  mock_resource "aws_dynamodb_table" {
    defaults = { arn = "arn:aws:dynamodb:us-east-1:000000000000:table/clnt-proj-qa-ddb-tel" }
  }

  mock_resource "aws_iot_certificate" {
    defaults = { private_key = "", public_key = "" }
  }

  mock_resource "aws_sqs_queue" {
    defaults = { url = "https://sqs.us-east-1.amazonaws.com/000000000000/fixture-queue" }
  }
}

variables {
  aws_region = "us-east-1"
  common_tags = {
    Client      = "clnt"
    Project     = "proj"
    Environment = "qa"
    Owner       = "SR1"
    CostCenter  = "shared"
  }
  environment        = "qa"
  inference_model_id = "amazon.nova-pro-v1:0"

  inference_function_packages = {
    confrm = { filename = "build/confrm.zip" }
    verify = { filename = "build/verify.zip" }
    estim  = { filename = "build/estim.zip" }
    thresh = { filename = "build/thresh.zip" }
  }

  kms_key_arns = {
    telemetry = "arn:aws:kms:us-east-1:000000000000:key/fixture-qa-telemetry"
    objects   = "arn:aws:kms:us-east-1:000000000000:key/fixture-qa-objects"
    records   = "arn:aws:kms:us-east-1:000000000000:key/fixture-qa-records"
    logs      = "arn:aws:kms:us-east-1:000000000000:key/fixture-qa-logs"
  }

  inference_targets = {
    alert_table_arn              = "arn:aws:dynamodb:us-east-1:000000000000:table/fixture-qa-alerts"
    alert_topic_arn              = "arn:aws:sns:us-east-1:000000000000:fixture-qa-alerts"
    drone_event_rule_arn_pattern = "arn:aws:events:us-east-1:000000000000:rule/fixture-qa-drone/*"
    drone_object_arn_pattern     = "arn:aws:s3:::fixture-qa-drone-objects/farms/*"
    mission_table_arn            = "arn:aws:dynamodb:us-east-1:000000000000:table/fixture-qa-missions"
    thresholds_table_arn         = "arn:aws:dynamodb:us-east-1:000000000000:table/fixture-qa-thresholds"
  }

  iot_logging_role_arn = "arn:aws:iam::000000000000:role/fixture-qa-iot-logging"
  iot_rule_role_arn    = "arn:aws:iam::000000000000:role/fixture-qa-iot-rule"

  telemetry_tls_security_policy = "IoTSecurityPolicy_TLS13_1_2_2022_10"
  telemetry_topic_namespace     = "fixture/qa/telemetry"

  farms = {
    f001 = {
      farm_id        = "fixture-farm-001"
      node_csr_paths = { crop = "fixtures/crop.csr", drying = "fixtures/drying.csr" }
    }
  }
}

run "farm_ingestion_comes_from_the_module" {
  command = plan

  assert {
    condition     = local.farm_ingestion == module.telemetry_ingestion.ingestion
    error_message = "The farm ingestion contract must be the ingestion output of the telemetry ingestion module."
  }

  assert {
    condition     = local.farm_ingestion.environment == "qa" && local.farm_ingestion.policy_name == "clnt-proj-qa-iot-pol"
    error_message = "The contract must carry the stack environment and the device policy named from client-project-environment."
  }

  assert {
    condition     = local.farm_ingestion.endpoint == output.iot_endpoint
    error_message = "The farms must connect to the data endpoint that the stack exposes."
  }

  assert {
    condition     = output.farm_telemetry_topics["f001"].drying == "fixture/qa/telemetry/clnt-proj-qa-f001-drying"
    error_message = "Node topics must be the module topic template filled with the node name."
  }
}

run "threshold_queue_sender_is_the_topic_rule" {
  command = plan

  assert {
    condition     = local.inference_functions["thresh"].queue_senders == { service_principals = ["iot.amazonaws.com"], source_arns = [module.telemetry_ingestion.topic_rule_arn] }
    error_message = "The only sender allowed on the threshold queue must be IoT Core through the topic rule of the module."
  }

  assert {
    condition     = output.topic_rule_arn == "arn:aws:iot:us-east-1:000000000000:rule/clnt_proj_qa_iot_rul" && output.topic_rule_name == "clnt_proj_qa_iot_rul"
    error_message = "The topic rule must be named from the underscored name prefix, as the security stack scopes the rule role."
  }
}

run "threshold_function_reads_the_module_table" {
  command = plan

  assert {
    condition     = local.inference_functions["thresh"].read.dynamodb_table_arns[0] == module.telemetry_ingestion.telemetry_table_arn
    error_message = "The threshold function must read the telemetry table of the module."
  }

  assert {
    condition     = output.telemetry_table_name == "clnt-proj-qa-ddb-tel" && output.telemetry_table_arn == module.telemetry_ingestion.telemetry_table_arn
    error_message = "The table output must be the module table, named as the security stack scopes the rule role."
  }
}

run "exposes_the_ingestion_outputs_for_later_tasks" {
  command = plan

  assert {
    condition     = output.error_queue_name == "clnt-proj-qa-iot-dlq" && output.domain_configuration_name == "clnt-proj-qa-iot-dom"
    error_message = "The error queue and the domain configuration must be named from the name prefix."
  }

  assert {
    condition     = output.iot_log_group_name == "AWSIotLogsV2"
    error_message = "The IoT Core log group must keep its fixed name."
  }
}

run "readings_are_kept_five_years" {
  command = plan

  assert {
    condition     = local.telemetry_retention_days == 1826 && local.log_retention_days == 365
    error_message = "Readings are kept 5 years (1826 days cover a leap day) and the logs 365 days."
  }
}

run "rule_role_must_be_an_iam_role_arn" {
  command = plan

  variables {
    iot_rule_role_arn = "fixture-qa-iot-rule"
  }

  expect_failures = [var.iot_rule_role_arn]
}

run "logging_role_must_be_an_iam_role_arn" {
  command = plan

  variables {
    iot_logging_role_arn = "fixture-qa-iot-logging"
  }

  expect_failures = [var.iot_logging_role_arn]
}

run "missing_logs_key_class_is_rejected" {
  command = plan

  variables {
    kms_key_arns = {
      telemetry = "arn:aws:kms:us-east-1:000000000000:key/fixture-qa-telemetry"
      objects   = "arn:aws:kms:us-east-1:000000000000:key/fixture-qa-objects"
      records   = "arn:aws:kms:us-east-1:000000000000:key/fixture-qa-records"
    }
  }

  expect_failures = [var.kms_key_arns]
}
