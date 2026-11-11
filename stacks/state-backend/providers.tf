# Bootstrap stack for the per-environment remote state buckets and their keys (box D02).
# Default provider. Cross-cutting tags are applied once through default_tags
# (PC-IAC-004 section 2.1).
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.common_tags, { Environment = var.environment })
  }
}
