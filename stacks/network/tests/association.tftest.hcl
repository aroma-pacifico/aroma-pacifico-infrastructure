# Native plan-mode tests of the single-center association (B05, box D05). All
# providers are mocked: no credential, account or network is involved. The
# network values are the synthetic pdn example; the accounts are fictitious.
mock_provider "aws" {
  override_during = plan

  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }

  mock_data "aws_availability_zones" {
    defaults = { zone_ids = ["use1-az1", "use1-az2", "use1-az4", "use1-az6"] }
  }
}

mock_provider "aws" {
  alias           = "principal"
  override_during = plan

  mock_resource "aws_ec2_transit_gateway_vpc_attachment" {
    defaults = { id = "tgw-attach-00000000000000001" }
  }
}

mock_provider "aws" {
  alias           = "network"
  override_during = plan

  mock_resource "aws_customer_gateway" {
    defaults = { id = "cgw-00000000000000001" }
  }
  mock_resource "aws_vpn_connection" {
    defaults = {
      id                            = "vpn-00000000000000001"
      transit_gateway_attachment_id = "tgw-attach-00000000000000002"
    }
  }
  mock_resource "aws_ec2_managed_prefix_list" {
    defaults = { id = "pl-00000000000000001" }
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

  center_association = {
    collection_center_key  = "cauca"
    workload_account_id    = "000000000000"
    workload_plan_role_arn = "arn:aws:iam::000000000000:role/fixture-workload-plan"
    network_plan_role_arn  = "arn:aws:iam::000000000001:role/fixture-network-plan"
    hub = {
      account_id               = "000000000001"
      region                   = "us-east-1"
      transit_gateway_id       = "tgw-0123456789abcdef0"
      customer_certificate_arn = "arn:aws:acm:us-east-1:000000000001:certificate/00000000-0000-0000-0000-000000000000"
    }
  }
}

run "cauca_connection" {
  command = plan

  variables {
    center_association = {
      collection_center_key  = "cauca"
      workload_account_id    = "000000000000"
      workload_plan_role_arn = "arn:aws:iam::000000000000:role/fixture-workload-plan"
      network_plan_role_arn  = "arn:aws:iam::000000000001:role/fixture-network-plan"
      hub = {
        account_id               = "000000000001"
        region                   = "us-east-1"
        transit_gateway_id       = "tgw-0123456789abcdef0"
        customer_certificate_arn = "arn:aws:acm:us-east-1:000000000001:certificate/00000000-0000-0000-0000-000000000000"
      }
    }
  }

  assert {
    condition     = length(output.association_routing_references) == 1 && output.association_routing_references[0].center_key == "cauca"
    error_message = "Exactly the cauca association may be planned."
  }

  assert {
    condition     = output.association_routing_references[0].vpn_connection_id == "vpn-00000000000000001" && output.association_routing_references[0].vpc_attachment_id == "tgw-attach-00000000000000001" && output.association_routing_references[0].prefix_list_id == "pl-00000000000000001"
    error_message = "The plan must expose the references that B07 consumes for the cloud-to-center link."
  }

  assert {
    condition     = var.collection_centers["cauca"].cidr_block == "10.41.0.0/16"
    error_message = "The association must use the approved departmental block of cauca."
  }
}

run "huila_connection" {
  command = plan

  variables {
    center_association = {
      collection_center_key  = "huila"
      workload_account_id    = "000000000000"
      workload_plan_role_arn = "arn:aws:iam::000000000000:role/fixture-workload-plan"
      network_plan_role_arn  = "arn:aws:iam::000000000001:role/fixture-network-plan"
      hub = {
        account_id               = "000000000001"
        region                   = "us-east-1"
        transit_gateway_id       = "tgw-0123456789abcdef0"
        customer_certificate_arn = "arn:aws:acm:us-east-1:000000000001:certificate/00000000-0000-0000-0000-000000000000"
      }
    }
  }

  assert {
    condition     = length(output.association_routing_references) == 1 && output.association_routing_references[0].center_key == "huila"
    error_message = "Exactly the huila association may be planned."
  }

  assert {
    condition     = output.association_routing_references[0].vpn_connection_id == "vpn-00000000000000001" && output.association_routing_references[0].vpc_attachment_id == "tgw-attach-00000000000000001" && output.association_routing_references[0].prefix_list_id == "pl-00000000000000001"
    error_message = "The plan must expose the references that B07 consumes for the cloud-to-center link."
  }

  assert {
    condition     = var.collection_centers["huila"].cidr_block == "10.42.0.0/16"
    error_message = "The association must use the approved departmental block of huila."
  }
}

run "tolima_connection" {
  command = plan

  variables {
    center_association = {
      collection_center_key  = "tolima"
      workload_account_id    = "000000000000"
      workload_plan_role_arn = "arn:aws:iam::000000000000:role/fixture-workload-plan"
      network_plan_role_arn  = "arn:aws:iam::000000000001:role/fixture-network-plan"
      hub = {
        account_id               = "000000000001"
        region                   = "us-east-1"
        transit_gateway_id       = "tgw-0123456789abcdef0"
        customer_certificate_arn = "arn:aws:acm:us-east-1:000000000001:certificate/00000000-0000-0000-0000-000000000000"
      }
    }
  }

  assert {
    condition     = length(output.association_routing_references) == 1 && output.association_routing_references[0].center_key == "tolima"
    error_message = "Exactly the tolima association may be planned."
  }

  assert {
    condition     = output.association_routing_references[0].vpn_connection_id == "vpn-00000000000000001" && output.association_routing_references[0].vpc_attachment_id == "tgw-attach-00000000000000001" && output.association_routing_references[0].prefix_list_id == "pl-00000000000000001"
    error_message = "The plan must expose the references that B07 consumes for the cloud-to-center link."
  }

  assert {
    condition     = var.collection_centers["tolima"].cidr_block == "10.43.0.0/16"
    error_message = "The association must use the approved departmental block of tolima."
  }
}

run "no_association_by_default" {
  command = plan

  variables {
    center_association = null
  }

  assert {
    condition     = length(output.association_routing_references) == 0
    error_message = "Without center_association nothing of the association may be planned."
  }
}

run "unknown_center" {
  command = plan

  variables {
    center_association = {
      collection_center_key  = "unknown"
      workload_account_id    = "000000000000"
      workload_plan_role_arn = "arn:aws:iam::000000000000:role/fixture-workload-plan"
      network_plan_role_arn  = "arn:aws:iam::000000000001:role/fixture-network-plan"
      hub = {
        account_id               = "000000000001"
        region                   = "us-east-1"
        transit_gateway_id       = "tgw-0123456789abcdef0"
        customer_certificate_arn = "arn:aws:acm:us-east-1:000000000001:certificate/00000000-0000-0000-0000-000000000000"
      }
    }
  }

  expect_failures = [var.center_association]
}

run "buenaventura_has_no_center" {
  command = plan

  variables {
    center_association = {
      collection_center_key  = "buenaventura"
      workload_account_id    = "000000000000"
      workload_plan_role_arn = "arn:aws:iam::000000000000:role/fixture-workload-plan"
      network_plan_role_arn  = "arn:aws:iam::000000000001:role/fixture-network-plan"
      hub = {
        account_id               = "000000000001"
        region                   = "us-east-1"
        transit_gateway_id       = "tgw-0123456789abcdef0"
        customer_certificate_arn = "arn:aws:acm:us-east-1:000000000001:certificate/00000000-0000-0000-0000-000000000000"
      }
    }
  }

  expect_failures = [var.center_association]
}

run "workload_role_in_wrong_account" {
  command = plan

  variables {
    center_association = {
      collection_center_key  = "cauca"
      workload_account_id    = "000000000000"
      workload_plan_role_arn = "arn:aws:iam::000000000009:role/fixture-workload-plan"
      network_plan_role_arn  = "arn:aws:iam::000000000001:role/fixture-network-plan"
      hub = {
        account_id               = "000000000001"
        region                   = "us-east-1"
        transit_gateway_id       = "tgw-0123456789abcdef0"
        customer_certificate_arn = "arn:aws:acm:us-east-1:000000000001:certificate/00000000-0000-0000-0000-000000000000"
      }
    }
  }

  expect_failures = [var.center_association]
}

run "hub_role_in_wrong_account" {
  command = plan

  variables {
    center_association = {
      collection_center_key  = "cauca"
      workload_account_id    = "000000000000"
      workload_plan_role_arn = "arn:aws:iam::000000000000:role/fixture-workload-plan"
      network_plan_role_arn  = "arn:aws:iam::000000000009:role/fixture-network-plan"
      hub = {
        account_id               = "000000000001"
        region                   = "us-east-1"
        transit_gateway_id       = "tgw-0123456789abcdef0"
        customer_certificate_arn = "arn:aws:acm:us-east-1:000000000001:certificate/00000000-0000-0000-0000-000000000000"
      }
    }
  }

  expect_failures = [var.center_association]
}

run "dev_is_isolated" {
  command = plan

  variables {
    environment = "dev"
  }

  expect_failures = [var.center_association]
}

run "qa_has_no_permanent_link" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.center_association]
}
