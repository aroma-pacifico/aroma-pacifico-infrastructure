# Plan-mode tests of the firewall rules wiring in the security stack (B07b,
# PC-IAC-018). Offline: the provider is mocked, so no credential, endpoint or
# account is involved. The values are the synthetic examples of
# environments/pdn/pdn.tfvars.example. The module is read from its pinned git tag
# at init time.
mock_provider "aws" {
  override_during = plan

  mock_data "aws_caller_identity" {
    defaults = { account_id = "mockaccount" }
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

run "pdn_plans_the_permanent_cloud_rules" {
  command = plan

  assert {
    condition     = toset(keys(output.security_group_ids)) == toset(["data_store", "resolver", "session_host"]) && toset(keys(output.prefix_list_ids)) == toset(["cc_device_mgmt", "cc_firewalls", "cc_ground_stations", "cc_logistics", "cc_staff"])
    error_message = "The plan must create three security groups and the five center prefix lists."
  }

  assert {
    condition     = toset(keys(output.web_acl_arns)) == toset(["api", "lookup"])
    error_message = "The plan must create the lookup and API web ACLs."
  }
}

run "no_rule_opens_the_internet" {
  command = plan

  # Every address that reaches a rule is one of these inputs or derives from them.
  assert {
    condition = alltrue([
      for cidr_block in concat(
        values(var.application_subnet_cidr_blocks),
        flatten([for center in values(local.firewall_collection_centers) : concat(
          center.device_management_cidr_blocks,
          center.staff_cidr_blocks,
          [center.firewall_cidr_block, center.ground_station_cidr_block, center.logistics_cidr_block]
        )])
      ) : !endswith(cidr_block, "/0") && !startswith(cidr_block, "0.")
    ])
    error_message = "No rule source may be the whole internet."
  }

  assert {
    condition     = alltrue([for cidr_block in concat(values(var.application_subnet_cidr_blocks), flatten([for center in values(local.firewall_collection_centers) : center.staff_cidr_blocks])) : startswith(cidr_block, "10.")])
    error_message = "Application and staff sources must be private 10.x blocks."
  }
}

run "internet_wide_application_source_is_rejected" {
  command = plan

  variables {
    application_subnet_cidr_blocks = { az1 = "0.0.0.0/0" }
  }

  expect_failures = [var.application_subnet_cidr_blocks]
}

run "api_web_acl_uses_the_asm_300_limit" {
  command = plan

  assert {
    condition     = output.web_acl_settings.api.rate_limit_per_5_minutes == 1000
    error_message = "The API web ACL must block above 1000 requests per source IP in 5 minutes (ASM-300)."
  }
}

run "lookup_limit_is_100_on_the_sack_path" {
  command = plan

  assert {
    condition     = output.web_acl_settings.lookup.rate_limit_per_5_minutes == 100 && output.web_acl_settings.lookup.rate_scope_path == "/s/"
    error_message = "The lookup web ACL must block above 100 requests per source IP in 5 minutes on /s/ (ASM-155)."
  }

  assert {
    condition     = output.web_acl_settings.lookup.allowed_path_prefixes == ["/assets/", "/s/"] && output.web_acl_settings.lookup.scope == "CLOUDFRONT"
    error_message = "The lookup web ACL must admit /assets/ and /s/ at the CloudFront scope."
  }
}

run "center_zones_follow_the_policy_prefix_lists" {
  command = plan

  assert {
    condition     = local.firewall_collection_centers["huila"].device_management_cidr_blocks == ["10.42.10.0/27", "10.42.10.32/28", "10.42.10.48/31"] && local.firewall_collection_centers["huila"].staff_cidr_blocks == ["10.42.1.0/24", "10.42.2.0/24"] && local.firewall_collection_centers["huila"].logistics_cidr_block == "10.42.3.0/24"
    error_message = "Zone blocks must follow section 5.1 of the firewall policy."
  }

  assert {
    condition     = length(flatten([for center in values(local.firewall_collection_centers) : center.device_management_cidr_blocks])) == 9 && length(flatten([for center in values(local.firewall_collection_centers) : center.staff_cidr_blocks])) == 6
    error_message = "The device management list holds 9 entries and the staff list 6."
  }
}

run "guest_blocks_never_enter_a_prefix_list" {
  command = plan

  assert {
    condition = alltrue(flatten([
      for center in values(local.firewall_collection_centers) : [
        for guest in center.guest_cidr_blocks : !contains(concat(
          center.device_management_cidr_blocks,
          center.staff_cidr_blocks,
          [center.firewall_cidr_block, center.ground_station_cidr_block, center.logistics_cidr_block]
        ), guest)
      ]
    ]))
    error_message = "A guest or transporter block must never be a prefix list entry."
  }
}

run "catalog_marks_rules_permanent_with_the_audit_flag" {
  command = plan

  assert {
    condition     = toset(keys(output.rule_catalog)) == toset(["CL-ADM-01", "CL-ADM-03", "CL-APP-02", "CL-DAT-02", "CL-DRN-02", "CL-PUB-01", "CL-TEL-03"])
    error_message = "The catalog must list exactly the permanent rows the stack wires."
  }

  assert {
    condition     = alltrue([for rule in values(output.rule_catalog) : rule.validity == "permanent"])
    error_message = "Every cataloged rule must be permanent; temporary rules are production changes (ASM-128)."
  }

  assert {
    condition     = alltrue([for id, rule in output.rule_catalog : rule.audit == (id != "CL-DAT-02")])
    error_message = "Every row marked Audit in the policy table keeps the audit flag (PD-125); CL-DAT-02 is Review."
  }

  assert {
    condition     = length(output.temporary_rule_ids) == 0
    error_message = "No temporary rule is declared in the stack."
  }
}

run "load_balancer_group_is_not_created" {
  command = plan

  assert {
    condition     = !contains(keys(output.security_group_ids), "load_balancer") && !contains(keys(output.rule_catalog), "CL-PUB-03")
    error_message = "The lookup front door is CloudFront with no load balancer, so CL-PUB-03 must not be created."
  }
}

run "endpoint_policies_name_only_the_platform_resources" {
  command = plan

  assert {
    condition     = length(local.platform_api_arns) == 1 && can(regex("^arn:aws:execute-api:us-east-1:[^:]+:fixturepd1/\\*$", local.platform_api_arns[0])) && local.drone_object_bucket_arn == "arn:aws:s3:::fixture-pdn-drone-objects"
    error_message = "The endpoint policies must name the platform API and the drone bucket only."
  }
}

run "endpoint_ids_without_the_required_keys_are_rejected" {
  command = plan

  variables {
    interface_endpoint_ids = { exapi = "vpce-00000000000000032" }
  }

  expect_failures = [var.interface_endpoint_ids]
}

run "vpc_id_with_the_wrong_shape_is_rejected" {
  command = plan

  variables {
    vpc_id = "not-a-vpc"
  }

  expect_failures = [var.vpc_id]
}
