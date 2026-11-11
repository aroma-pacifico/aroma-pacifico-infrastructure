# Synthetic fixtures for the pdn association plan against the Floci emulator
# (PC-IAC-028). Load after environments/pdn/pdn.tfvars.example. Every identifier
# is fictitious and non-operational: the emulator answers with the single
# all-zero account, so both owners coincide and the cross-account accepter is
# not part of this graph.
center_association = {
  collection_center_key  = "cauca"
  workload_account_id    = "000000000000"
  workload_plan_role_arn = "arn:aws:iam::000000000000:role/fixture-workload-plan"
  network_plan_role_arn  = "arn:aws:iam::000000000000:role/fixture-network-plan"
  hub = {
    account_id               = "000000000000"
    region                   = "us-east-1"
    transit_gateway_id       = "tgw-0123456789abcdef0"
    customer_certificate_arn = "arn:aws:acm:us-east-1:000000000000:certificate/00000000-0000-0000-0000-000000000000"
  }
}
