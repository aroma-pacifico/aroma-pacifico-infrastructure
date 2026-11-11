# Permanent cloud firewall rules (box D07, B07b). One call to the reference
# module, pinned by SemVer tag (PC-IAC-015). Security groups and web ACLs belong
# to the security domain (PC-IAC-022 section 3.2, ADR-003), so the module is wired
# here and reads the network identifiers as input variables (PC-IAC-019).
locals {
  # Values stated by the architecture documents. Nothing here is a new assumption.
  # WAF scope: the public lookup front door is CloudFront (sack-and-trip 7.1). The
  # module applies one scope to both web ACLs, so the API web ACL shares it.
  waf_scope = "CLOUDFRONT"

  # ASM-300: 1,000 requests per source IP in 5 minutes on the application API.
  api_rate_limit = 1000

  # ASM-155 and sack-and-trip 7.3: above 100 requests to /s/ in 5 minutes the
  # lookup blocks the source IP. ASM-129 and 7.3: GET and HEAD are allowed on /,
  # /assets/* and /s/*; the module adds the exact path / itself.
  lookup_rate_limit            = 100
  lookup_rate_scope_path       = "/s/"
  lookup_allowed_path_prefixes = ["/assets/", "/s/"]

  # Zone layout of every center (collection-center-network 3.1 and firewall
  # policy 5.1), derived from the /16 so that no address is typed twice:
  # Gerencia 1 and Soporte 2 (staff), Logistica 3, Transporte 4 and Visitantes 5
  # (guests), Servidores locales 10 (device management: .0/27, .32/28 and
  # .48/31 give the addresses .1 to .49 without the printers).
  firewall_collection_centers = {
    for name, center in var.collection_centers : name => {
      firewall_cidr_block       = center.firewall_cidr_block
      ground_station_cidr_block = center.ground_station_cidr_block
      logistics_cidr_block      = cidrsubnet(center.cidr_block, 8, 3)
      staff_cidr_blocks         = [cidrsubnet(center.cidr_block, 8, 1), cidrsubnet(center.cidr_block, 8, 2)]
      guest_cidr_blocks         = [cidrsubnet(center.cidr_block, 8, 4), cidrsubnet(center.cidr_block, 8, 5)]
      device_management_cidr_blocks = [
        cidrsubnet(cidrsubnet(center.cidr_block, 8, 10), 3, 0),
        cidrsubnet(cidrsubnet(center.cidr_block, 8, 10), 4, 2),
        cidrsubnet(cidrsubnet(center.cidr_block, 8, 10), 7, 24),
      ]
    }
  }

  # Endpoint policy targets (CL-APP-02, CL-DRN-02). The account comes from the
  # caller identity, so no ARN is stored in a variable file (PC-IAC-016).
  platform_api_arns       = [for id in var.platform_api_ids : "arn:${local.partition}:execute-api:${var.aws_region}:${local.account_id}:${id}/*"]
  drone_object_bucket_arn = "arn:${local.partition}:s3:::${var.drone_object_bucket_name}"
}

module "firewall_rules" {
  source = "git::https://github.com/aroma-pacifico/aroma-pacifico-terraform-modules.git//modules/firewall-rules?ref=v0.5.0"

  # The module consumes the aws.project alias (PC-IAC-005).
  providers = { aws.project = aws }

  client          = local.client
  project         = local.project
  environment     = var.environment
  name_prefix     = local.name_prefix
  additional_tags = local.common_tags

  vpc_id             = var.vpc_id
  collection_centers = local.firewall_collection_centers

  # CL-DAT-02: only the application tier reaches the data store.
  application_cidr_blocks = values(var.application_subnet_cidr_blocks)
  data_store_ports        = var.data_store_ports

  # CL-APP-02 and CL-DRN-02: endpoint policies on the execute-api and S3
  # interface endpoints of the network stack.
  api_endpoint = {
    endpoint_id   = var.interface_endpoint_ids["exapi"]
    resource_arns = local.platform_api_arns
  }
  drone_object_endpoint = {
    bucket_arn  = local.drone_object_bucket_arn
    endpoint_id = var.interface_endpoint_ids["s3"]
  }

  # CL-PUB-01 and CL-TEL-03: the two web ACLs.
  waf_scope                    = local.waf_scope
  api_rate_limit               = local.api_rate_limit
  lookup_rate_limit            = local.lookup_rate_limit
  lookup_rate_scope_path       = local.lookup_rate_scope_path
  lookup_allowed_path_prefixes = local.lookup_allowed_path_prefixes

  # CL-PUB-03: the front door is CloudFront with no load balancer (PD-051 closed,
  # sack-and-trip 7.2), so the load balancer group is not created.
  enable_cloudfront_origin_rule = false

  # ASM-128: temporary rules are added and removed as production changes, each
  # with its own release note, so none is declared here.
  temporary_rules = {}
}
