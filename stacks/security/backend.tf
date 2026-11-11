# Partial S3 backend (PC-IAC-008, ADR-003). Bucket, key, region, encryption and
# locking are injected at init time from the per-environment backend file.
# This stack never keeps local state.
terraform {
  backend "s3" {}
}
