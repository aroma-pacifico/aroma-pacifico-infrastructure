# Plan-mode tests of the network stack (B04b, PC-IAC-018). Offline: the provider
# is mocked, so no credential, endpoint or account is involved. The values are
# the synthetic examples of environments/<env>/<env>.tfvars.example.
mock_provider "aws" {
  override_during = plan

  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }

  mock_data "aws_availability_zones" {
    defaults = { zone_ids = ["use1-az1", "use1-az2", "use1-az4", "use1-az6"] }
  }
}

# The association providers (D05) are configured even when no association is
# selected, so they are mocked too.
mock_provider "aws" {
  alias           = "principal"
  override_during = plan
}

mock_provider "aws" {
  alias           = "network"
  override_during = plan
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
  environment                          = "pdn"
  organization_id                      = "o-a1b2c3d4e5"
  vpc_cidr_block                       = "10.82.0.0/16"
  collection_center_summary_cidr_block = "10.40.0.0/13"
  transit_gateway_id                   = "tgw-0123456789abcdef0"
  data_store_ports                     = [5432]

  subnets = {
    public_query         = { az1 = "10.82.0.0/22", az2 = "10.82.4.0/22", az3 = "10.82.8.0/22" }
    telemetry_ingress    = { az1 = "10.82.16.0/22", az2 = "10.82.20.0/22", az3 = "10.82.24.0/22" }
    drone_object_ingress = { az1 = "10.82.32.0/22", az2 = "10.82.36.0/22", az3 = "10.82.40.0/22" }
    application          = { az1 = "10.82.48.0/22", az2 = "10.82.52.0/22", az3 = "10.82.56.0/22" }
    data                 = { az1 = "10.82.64.0/22", az2 = "10.82.68.0/22", az3 = "10.82.72.0/22" }
    object_storage       = { az1 = "10.82.80.0/22", az2 = "10.82.84.0/22", az3 = "10.82.88.0/22" }
    administration       = { az1 = "10.82.96.0/22", az2 = "10.82.100.0/22", az3 = "10.82.104.0/22" }
    transit              = { az1 = "10.82.240.0/28", az2 = "10.82.240.16/28", az3 = "10.82.240.32/28" }
  }

  collection_centers = {
    cauca  = { cidr_block = "10.41.0.0/16", firewall_cidr_block = "10.41.20.1/32", ground_station_cidr_block = "10.41.2.10/32" }
    huila  = { cidr_block = "10.42.0.0/16", firewall_cidr_block = "10.42.20.1/32", ground_station_cidr_block = "10.42.2.10/32" }
    tolima = { cidr_block = "10.43.0.0/16", firewall_cidr_block = "10.43.20.1/32", ground_station_cidr_block = "10.43.2.10/32" }
  }

  interface_endpoints = {
    exapi = { service = "execute-api", tier = "application" }
    s3    = { service = "s3", tier = "object_storage" }
    logs  = { service = "logs", tier = "administration" }
  }
}

run "pdn_plans_eight_tiers_outside_the_centers" {
  command = plan

  assert {
    condition     = length(output.subnet_ids) == 8 && alltrue([for azs in values(output.subnet_ids) : length(azs) == 3])
    error_message = "The plan must create eight tiers with three subnets each."
  }

  assert {
    condition     = length(output.route_table_ids) == 8 && length(output.network_acl_ids) == 8
    error_message = "The plan must create one route table and one network ACL per tier."
  }

  assert {
    condition     = length(output.transit_attachment_subnet_ids) == 3
    error_message = "The plan must expose one transit attachment subnet per Availability Zone slot."
  }

  assert {
    condition = alltrue([
      for cidr_block in concat([output.vpc_cidr_block], flatten([for azs in values(output.subnet_cidr_blocks) : values(azs)])) :
      !contains(["10.41", "10.42", "10.43"], join(".", slice(split(".", cidrhost(cidr_block, 0)), 0, 2)))
    ])
    error_message = "The VPC and every subnet must stay clear of 10.41.0.0/16, 10.42.0.0/16 and 10.43.0.0/16."
  }
}

run "dev_uses_its_own_block" {
  command = plan

  variables {
    environment    = "dev"
    vpc_cidr_block = "10.80.0.0/16"
    subnets = {
      public_query         = { az1 = "10.80.0.0/22", az2 = "10.80.4.0/22", az3 = "10.80.8.0/22" }
      telemetry_ingress    = { az1 = "10.80.16.0/22", az2 = "10.80.20.0/22", az3 = "10.80.24.0/22" }
      drone_object_ingress = { az1 = "10.80.32.0/22", az2 = "10.80.36.0/22", az3 = "10.80.40.0/22" }
      application          = { az1 = "10.80.48.0/22", az2 = "10.80.52.0/22", az3 = "10.80.56.0/22" }
      data                 = { az1 = "10.80.64.0/22", az2 = "10.80.68.0/22", az3 = "10.80.72.0/22" }
      object_storage       = { az1 = "10.80.80.0/22", az2 = "10.80.84.0/22", az3 = "10.80.88.0/22" }
      administration       = { az1 = "10.80.96.0/22", az2 = "10.80.100.0/22", az3 = "10.80.104.0/22" }
      transit              = { az1 = "10.80.240.0/28", az2 = "10.80.240.16/28", az3 = "10.80.240.32/28" }
    }
  }

  assert {
    condition     = output.vpc_cidr_block == "10.80.0.0/16"
    error_message = "The dev VPC must be 10.80.0.0/16, distinct from the other environments and the centers."
  }
}

run "qa_uses_its_own_block" {
  command = plan

  variables {
    environment    = "qa"
    vpc_cidr_block = "10.81.0.0/16"
    subnets = {
      public_query         = { az1 = "10.81.0.0/22", az2 = "10.81.4.0/22", az3 = "10.81.8.0/22" }
      telemetry_ingress    = { az1 = "10.81.16.0/22", az2 = "10.81.20.0/22", az3 = "10.81.24.0/22" }
      drone_object_ingress = { az1 = "10.81.32.0/22", az2 = "10.81.36.0/22", az3 = "10.81.40.0/22" }
      application          = { az1 = "10.81.48.0/22", az2 = "10.81.52.0/22", az3 = "10.81.56.0/22" }
      data                 = { az1 = "10.81.64.0/22", az2 = "10.81.68.0/22", az3 = "10.81.72.0/22" }
      object_storage       = { az1 = "10.81.80.0/22", az2 = "10.81.84.0/22", az3 = "10.81.88.0/22" }
      administration       = { az1 = "10.81.96.0/22", az2 = "10.81.100.0/22", az3 = "10.81.104.0/22" }
      transit              = { az1 = "10.81.240.0/28", az2 = "10.81.240.16/28", az3 = "10.81.240.32/28" }
    }
  }

  assert {
    condition     = output.vpc_cidr_block == "10.81.0.0/16"
    error_message = "The qa VPC must be 10.81.0.0/16, distinct from the other environments and the centers."
  }
}

run "vpc_overlapping_a_center_is_rejected" {
  command = plan

  variables {
    vpc_cidr_block = "10.42.0.0/16"
  }

  expect_failures = [var.vpc_cidr_block]
}

run "vpc_inside_a_reserved_center_block_is_rejected" {
  command = plan

  variables {
    vpc_cidr_block = "10.43.128.0/17"
  }

  expect_failures = [var.vpc_cidr_block]
}

run "missing_reserved_center_is_rejected" {
  command = plan

  variables {
    collection_centers = {
      cauca = { cidr_block = "10.41.0.0/16", firewall_cidr_block = "10.41.20.1/32", ground_station_cidr_block = "10.41.2.10/32" }
    }
  }

  expect_failures = [var.collection_centers]
}
