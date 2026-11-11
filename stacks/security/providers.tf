# Security domain stack: keys, roles and baseline controls (box D06).
# Default provider. Cross-cutting tags are applied once through default_tags
# (PC-IAC-004 section 2.1).
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.common_tags, { Environment = var.environment })
  }
}
