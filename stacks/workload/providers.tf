# Workload domain stack: farm, ingestion and inference function (boxes D08 to D10).
# Default provider. Cross-cutting tags are applied once through default_tags
# (PC-IAC-004 section 2.1).
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}
