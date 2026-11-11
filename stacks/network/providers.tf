# Network domain stack of the pattern environment (box D04) and association root
# of box D05. Cross-cutting tags are applied once through default_tags
# (PC-IAC-004 section 2.1).
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

# D05 association: workload account (owns the VPC attachment) and hub account
# (owns the customer gateway, VPN and prefix list), PC-IAC-005. Without an
# association both are unused and carry no account assertion.
provider "aws" {
  alias               = "principal"
  region              = var.aws_region
  allowed_account_ids = var.center_association == null ? null : [var.center_association.workload_account_id]

  dynamic "assume_role" {
    for_each = var.center_association == null ? [] : [var.center_association.workload_plan_role_arn]
    content {
      role_arn = assume_role.value
    }
  }

  default_tags {
    tags = var.common_tags
  }
}

provider "aws" {
  alias               = "network"
  region              = var.aws_region
  allowed_account_ids = var.center_association == null ? null : [var.center_association.hub.account_id]

  dynamic "assume_role" {
    for_each = var.center_association == null ? [] : [var.center_association.network_plan_role_arn]
    content {
      role_arn = assume_role.value
    }
  }

  default_tags {
    tags = var.common_tags
  }
}
