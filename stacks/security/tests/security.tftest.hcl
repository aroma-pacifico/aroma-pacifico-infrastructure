# Plan-mode tests of the security stack (B06b, PC-IAC-018). Offline: the provider
# is mocked, so no credential, endpoint or account is involved. The values are
# the synthetic examples of environments/<env>/<env>.tfvars.example. The module
# is read from its pinned git tag at init time.
mock_provider "aws" {
  override_during = plan

  mock_data "aws_caller_identity" {
    defaults = { account_id = "000000000000" }
  }

  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }

  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }

  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

variables {
  aws_region = "us-east-1"
  common_tags = {
    Client      = "clnt"
    Project     = "proj"
    Environment = "pdn"
    Owner       = "SR1"
    CostCenter  = "shared"
  }
  environment               = "pdn"
  security_apply_role_names = ["security-apply"]
  break_glass_role_patterns = ["aws-reserved/sso.amazonaws.com/*/AWSReservedSSO_BreakGlass_*"]
  key_user_role_names = {
    telemetry = ["clnt-proj-pdn-rol-telemetry"]
    records   = ["clnt-proj-pdn-rol-telemetry"]
    objects   = ["clnt-proj-pdn-rol-drone"]
  }

  # Firewall rules inputs (B07b); the rules themselves are tested in
  # firewall_rules.tftest.hcl.
  vpc_id                         = "vpc-00000000000000003"
  application_subnet_cidr_blocks = { az1 = "10.82.48.0/22", az2 = "10.82.52.0/22", az3 = "10.82.56.0/22" }
  data_store_ports               = [5432]
  platform_api_ids               = ["fixturepd1"]
  drone_object_bucket_name       = "fixture-pdn-drone-objects"
  interface_endpoint_ids = {
    exapi = "vpce-00000000000000032"
    s3    = "vpce-00000000000000033"
  }
  collection_centers = {
    cauca  = { cidr_block = "10.41.0.0/16", firewall_cidr_block = "10.41.20.1/32", ground_station_cidr_block = "10.41.2.10/32" }
    huila  = { cidr_block = "10.42.0.0/16", firewall_cidr_block = "10.42.20.1/32", ground_station_cidr_block = "10.42.2.10/32" }
    tolima = { cidr_block = "10.43.0.0/16", firewall_cidr_block = "10.43.20.1/32", ground_station_cidr_block = "10.43.2.10/32" }
  }
}

run "pdn_plans_eight_keys_and_two_pools" {
  command = plan

  assert {
    condition     = length(output.kms_key_arns) == 8
    error_message = "The plan must create one customer-managed key per data class."
  }

  assert {
    condition     = length(output.cognito_group_names) == 7
    error_message = "The plan must create the seven Cognito groups."
  }

  assert {
    condition     = output.secure_transport_policy_statements_json == null
    error_message = "No bucket is protected by default, so no transport policy is rendered."
  }
}

run "roles_resolve_to_arns_of_the_caller_account" {
  command = plan

  assert {
    condition     = module.security.kms_key_alias_names["logs"] == "alias/clnt-proj-pdn-logs"
    error_message = "Key aliases must follow the client-project-environment prefix."
  }

  assert {
    condition     = local.key_administrator_arns == ["arn:aws:iam::000000000000:role/security-apply"]
    error_message = "The apply role name must resolve to an ARN in the caller account."
  }

  assert {
    condition     = local.key_user_arns["objects"] == ["arn:aws:iam::000000000000:role/clnt-proj-pdn-rol-drone"] && local.break_glass_role_arn_patterns == ["arn:aws:iam::000000000000:role/aws-reserved/sso.amazonaws.com/*/AWSReservedSSO_BreakGlass_*"]
    error_message = "Key users and break-glass patterns must resolve to ARNs in the caller account."
  }
}

run "protected_buckets_render_the_transport_policy" {
  command = plan

  variables {
    protected_bucket_names = ["clnt-proj-pdn-drone-objects"]
  }

  assert {
    condition     = local.protected_bucket_arns == ["arn:aws:s3:::clnt-proj-pdn-drone-objects"]
    error_message = "Bucket names must resolve to bucket ARNs."
  }
}

run "dev_and_qa_plan_with_the_same_stack" {
  command = plan

  variables {
    environment = "dev"
    common_tags = {
      Client      = "clnt"
      Project     = "proj"
      Environment = "dev"
      Owner       = "SR1"
      CostCenter  = "shared"
    }
  }

  assert {
    condition     = module.security.kms_key_alias_names["telemetry"] == "alias/clnt-proj-dev-telemetry"
    error_message = "The environment must feed the name prefix."
  }
}

run "environment_outside_the_set_is_rejected" {
  command = plan

  variables {
    environment = "staging"
  }

  expect_failures = [var.environment]
}

run "empty_apply_role_list_is_rejected" {
  command = plan

  variables {
    security_apply_role_names = []
  }

  expect_failures = [var.security_apply_role_names]
}

run "bare_break_glass_wildcard_is_rejected" {
  command = plan

  variables {
    break_glass_role_patterns = ["*"]
  }

  expect_failures = [var.break_glass_role_patterns]
}

run "arn_instead_of_bucket_name_is_rejected" {
  command = plan

  variables {
    protected_bucket_names = ["arn:aws:s3:::clnt-proj-pdn-drone-objects"]
  }

  expect_failures = [var.protected_bucket_names]
}
