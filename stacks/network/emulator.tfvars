# Synthetic fixtures for speculative plans against the Floci emulator
# (PC-IAC-028) and for the Infracost scan. Every identifier below is fictitious
# and non-operational (all-zero accounts, placeholder resource references); the
# emulator answers with the single all-zero account, so both owners coincide
# and the cross-account accepter is not part of this graph. Load it after the
# environment example, which it overrides: permanent links exist only in pdn.
aws_region  = "us-east-1"
environment = "pdn"

common_tags = {
  Client      = "fx"
  Project     = "cf"
  Environment = "pdn"
  Owner       = "SR1"
  CostCenter  = "collection-centers"
}

collection_center = {
  key = "cauca"
}

network = {
  environment                   = "pdn"
  account_id                    = "000000000000"
  vpc_id                        = "vpc-0123456789abcdef0"
  vpc_cidr_block                = "10.82.0.0/16"
  transit_attachment_subnet_ids = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1", "subnet-0123456789abcdef2"]
}

hub = {
  account_id               = "000000000000"
  region                   = "us-east-1"
  transit_gateway_id       = "tgw-0123456789abcdef0"
  customer_certificate_arn = "arn:aws:acm:us-east-1:000000000000:certificate/00000000-0000-0000-0000-000000000000"
}

network_plan_role_arn  = "arn:aws:iam::000000000000:role/fixture-network-plan"
workload_plan_role_arn = "arn:aws:iam::000000000000:role/fixture-workload-plan"
