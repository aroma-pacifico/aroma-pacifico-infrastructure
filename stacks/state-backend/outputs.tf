output "backend_configuration" {
  description = "Non-secret partial backend settings of each state domain, to copy into its backends/<env>.s3.tfbackend file."
  value = {
    for domain in keys(var.domain_access) : domain => {
      bucket       = module.state_backend.state_bucket_name
      key          = "${domain}/terraform.tfstate"
      region       = module.state_backend.backend_region
      encrypt      = true
      kms_key_id   = module.state_backend.state_kms_key_arn
      use_lockfile = true
    }
  }
}

output "state_bucket_name" {
  description = "Name of the state bucket of this environment."
  value       = module.state_backend.state_bucket_name
}
