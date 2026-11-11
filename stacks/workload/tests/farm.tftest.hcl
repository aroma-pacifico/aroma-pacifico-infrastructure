# Plan-mode tests of the farm wiring of the workload stack (B08b, PC-IAC-018).
# Offline: the provider is mocked, so no credential, endpoint or account is
# involved. The CSRs are the synthetic fixtures of stacks/workload/fixtures.
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
  # Certificates created from a CSR return no key material.
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

run "plans_one_farm_with_its_two_nodes" {
  command = plan

  assert {
    condition     = output.farm_node_names["f001"] == { crop = "clnt-proj-qa-f001-crop", drying = "clnt-proj-qa-f001-drying" }
    error_message = "One farm must expose exactly its crop and drying node identities, named from client-project-environment and the farm key."
  }

  assert {
    condition     = output.farm_telemetry_topics["f001"].crop == "fixture/qa/telemetry/clnt-proj-qa-f001-crop"
    error_message = "Node topics must be rendered from the injected ingestion topic template."
  }

  assert {
    condition     = length(output.farm_certificate_arns["f001"]) == 2
    error_message = "Each node of the farm must have its own certificate."
  }
}

run "no_farm_plans_no_farm_resources" {
  command = plan

  variables {
    farms = {}
  }

  assert {
    condition     = length(output.farm_node_names) == 0
    error_message = "An empty farm list must plan no farm identity."
  }
}

run "long_farm_key_is_rejected" {
  command = plan

  variables {
    farms = {
      farm01 = {
        farm_id        = "fixture-farm-001"
        node_csr_paths = { crop = "fixtures/crop.csr", drying = "fixtures/drying.csr" }
      }
    }
  }

  expect_failures = [var.farms]
}

run "farm_without_drying_node_is_rejected" {
  command = plan

  variables {
    farms = {
      f001 = {
        farm_id        = "fixture-farm-001"
        node_csr_paths = { crop = "fixtures/crop.csr" }
      }
    }
  }

  expect_failures = [var.farms]
}
