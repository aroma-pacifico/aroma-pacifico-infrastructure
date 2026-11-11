# Network domain stack of the pattern environment (box D04) and association root
# of box D05. Cross-cutting tags are applied once through default_tags
# (PC-IAC-004 section 2.1).
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

# Workload account: owns the VPC attachment (PC-IAC-005 alias "principal").
provider "aws" {
  alias               = "principal"
  region              = var.aws_region
  allowed_account_ids = [var.network.account_id]

  assume_role {
    role_arn = var.workload_plan_role_arn
  }

  default_tags {
    tags = var.common_tags
  }
}

# Hub (network) account: owns the customer gateway, VPN and prefix list.
provider "aws" {
  alias               = "network"
  region              = var.aws_region
  allowed_account_ids = [var.hub.account_id]

  assume_role {
    role_arn = var.network_plan_role_arn
  }

  default_tags {
    tags = var.common_tags
  }
}
