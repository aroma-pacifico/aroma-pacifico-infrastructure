# Native plan-mode tests of the single-center association root (box D05). All
# providers are mocked: no credentials, no account and no network are used.
mock_provider "aws" {}

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
  aws_region        = "us-east-1"
  common_tags       = { Client = "fx", Project = "cf", Environment = "pdn", Owner = "SR1", CostCenter = "collection-centers" }
  collection_center = { key = "cauca" }
  environment       = "pdn"
  network = {
    environment                   = "pdn"
    account_id                    = "000000000000"
    vpc_id                        = "vpc-0123456789abcdef0"
    vpc_cidr_block                = "10.82.0.0/16"
    transit_attachment_subnet_ids = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  }
  hub = {
    account_id               = "000000000001"
    region                   = "us-east-1"
    transit_gateway_id       = "tgw-0123456789abcdef0"
    customer_certificate_arn = "arn:aws:acm:us-east-1:000000000001:certificate/00000000-0000-0000-0000-000000000000"
  }
  network_plan_role_arn  = "arn:aws:iam::000000000001:role/fixture-network-plan"
  workload_plan_role_arn = "arn:aws:iam::000000000000:role/fixture-workload-plan"
}

run "cauca_connection" {
  command = plan

  variables {
    collection_center = { key = "cauca" }
  }

  assert {
    condition     = output.selected_center == { key = "cauca", department = "cauca", cidr_block = "10.41.0.0/16", environment = "pdn" }
    error_message = "Only the cauca association and its approved departmental block may be planned."
  }

  assert {
    condition     = output.routing_references.vpn_connection_id == "vpn-00000000000000001" && output.routing_references.vpc_attachment_id == "tgw-attach-00000000000000001" && output.routing_references.prefix_list_id == "pl-00000000000000001"
    error_message = "The plan must expose the references that B07 consumes for the cloud-to-center link."
  }
}

run "huila_connection" {
  command = plan

  variables {
    collection_center = { key = "huila" }
  }

  assert {
    condition     = output.selected_center == { key = "huila", department = "huila", cidr_block = "10.42.0.0/16", environment = "pdn" }
    error_message = "Only the huila association and its approved departmental block may be planned."
  }

  assert {
    condition     = output.routing_references.vpn_connection_id == "vpn-00000000000000001" && output.routing_references.vpc_attachment_id == "tgw-attach-00000000000000001" && output.routing_references.prefix_list_id == "pl-00000000000000001"
    error_message = "The plan must expose the references that B07 consumes for the cloud-to-center link."
  }
}

run "tolima_connection" {
  command = plan

  variables {
    collection_center = { key = "tolima", department = "tolima", cidr_block = "10.43.0.0/16" }
  }

  assert {
    condition     = output.selected_center == { key = "tolima", department = "tolima", cidr_block = "10.43.0.0/16", environment = "pdn" }
    error_message = "Only the tolima association and its approved departmental block may be planned."
  }

  assert {
    condition     = output.routing_references.vpn_connection_id == "vpn-00000000000000001" && output.routing_references.vpc_attachment_id == "tgw-attach-00000000000000001" && output.routing_references.prefix_list_id == "pl-00000000000000001"
    error_message = "The plan must expose the references that B07 consumes for the cloud-to-center link."
  }
}

run "unknown_center" {
  command = plan

  variables {
    collection_center = { key = "unknown" }
  }

  expect_failures = [var.collection_center]
}

run "buenaventura_has_no_center" {
  command = plan

  variables {
    collection_center = { key = "buenaventura" }
  }

  expect_failures = [var.collection_center]
}

run "wrong_department" {
  command = plan

  variables {
    collection_center = { key = "cauca", department = "huila" }
  }

  expect_failures = [var.collection_center]
}

run "wrong_cidr" {
  command = plan

  variables {
    collection_center = { key = "cauca", cidr_block = "10.42.0.0/16" }
  }

  expect_failures = [var.collection_center]
}

run "dev_is_isolated" {
  command = plan

  variables {
    environment = "dev"
  }

  expect_failures = [var.environment]
}

run "qa_has_no_permanent_link" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.environment]
}

run "workload_role_in_wrong_account" {
  command = plan

  variables {
    workload_plan_role_arn = "arn:aws:iam::000000000009:role/fixture-workload-plan"
  }

  expect_failures = [var.workload_plan_role_arn]
}

run "hub_role_in_wrong_account" {
  command = plan

  variables {
    network_plan_role_arn = "arn:aws:iam::000000000009:role/fixture-network-plan"
  }

  expect_failures = [var.network_plan_role_arn]
}
