# Plan-mode tests of the inference functions wiring of the workload stack
# (B10b, PC-IAC-018). Offline: the provider is mocked, so no credential,
# endpoint or account is involved. The values are the synthetic examples of
# environments/<env>/<env>.tfvars.example.
mock_provider "aws" {
  override_during = plan

  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }

  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }

  # The queue URL is computed by AWS; the mock returns the documented shape so
  # that the threshold_queue_url contract of the telemetry ingestion can be asserted.
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

  # Farm inputs (B08b) are required by the stack; no farm is planned here.
  farms = {}
}

run "plans_the_four_functions_of_the_design" {
  command = plan

  assert {
    condition     = toset(keys(output.queue_urls)) == toset(["confrm", "verify", "estim", "thresh"])
    error_message = "The stack must plan the confirmation, verification, estimation and threshold functions."
  }

  assert {
    condition     = length(output.dead_letter_queue_names) == 4
    error_message = "Every function must have its own dead-letter queue."
  }

  assert {
    condition     = output.inference_function_names["thresh"] == "clnt-proj-qa-lmb-thresh"
    error_message = "Function names must derive from client-project-environment."
  }
}

run "exposes_the_threshold_queue_for_telemetry_ingestion" {
  command = plan

  assert {
    condition     = output.threshold_queue_url == output.queue_urls["thresh"]
    error_message = "threshold_queue_url must be the queue of the threshold function."
  }

  assert {
    condition     = can(regex("^https://sqs\\.[a-z0-9-]+\\.amazonaws\\.com/[0-9]{12}/[A-Za-z0-9_-]{1,80}$", output.threshold_queue_url))
    error_message = "threshold_queue_url must have the SQS URL shape that modules/telemetry-ingestion validates."
  }
}

run "missing_function_package_is_rejected" {
  command = plan

  variables {
    inference_function_packages = {
      confrm = { filename = "build/confrm.zip" }
    }
  }

  expect_failures = [var.inference_function_packages]
}

run "missing_key_class_is_rejected" {
  command = plan

  variables {
    kms_key_arns = {
      records = "arn:aws:kms:us-east-1:000000000000:key/fixture-qa-records"
      logs    = "arn:aws:kms:us-east-1:000000000000:key/fixture-qa-logs"
    }
  }

  expect_failures = [var.kms_key_arns]
}
