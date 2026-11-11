# Plan-mode checks of the state-backend root (B02, PC-IAC-018). The provider is
# mocked, so no account, endpoint or credential is involved. The module is read
# from its pinned git tag at init time.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

variables {
  aws_region  = "us-east-1"
  environment = "qa"
  common_tags = {
    Client      = "cli"
    Project     = "prj"
    Environment = "qa"
    Owner       = "SR1"
    CostCenter  = "shared"
  }
  key_administrator_role_names    = ["state-backend-apply"]
  configuration_reader_role_names = ["state-auditor"]
  break_glass_role_patterns       = ["aws-reserved/sso.amazonaws.com/*/AWSReservedSSO_BreakGlass_*"]
  domain_access = {
    network = {
      plan_role_names  = ["network-plan"]
      write_role_names = ["network-apply"]
    }
    security = {
      plan_role_names  = ["security-plan"]
      write_role_names = ["security-apply"]
    }
    workload = {
      plan_role_names  = ["workload-plan"]
      write_role_names = ["workload-apply"]
    }
    state-backend = {
      plan_role_names  = ["state-backend-plan"]
      write_role_names = ["state-backend-apply"]
    }
  }
}

run "environment_bucket_and_locking" {
  command = plan

  assert {
    condition     = module.state_backend.state_bucket_name == "cli-prj-qa-state"
    error_message = "The bucket name must be client-project-environment-state."
  }

  assert {
    condition     = alltrue([for domain, config in output.backend_configuration : config.use_lockfile && config.encrypt && config.key == "${domain}/terraform.tfstate"])
    error_message = "Every domain needs an encrypted, locked backend with its own state key."
  }

  assert {
    condition     = toset(keys(output.backend_configuration)) == toset(["network", "security", "workload", "state-backend"])
    error_message = "The four approved state domains must be covered."
  }
}

run "state_is_separated_per_environment" {
  command = plan

  variables {
    environment = "pdn"
    common_tags = {
      Client      = "cli"
      Project     = "prj"
      Environment = "pdn"
      Owner       = "SR1"
      CostCenter  = "shared"
    }
  }

  assert {
    condition     = module.state_backend.state_bucket_name == "cli-prj-pdn-state"
    error_message = "Production must have its own bucket, never the qa one."
  }
}

run "rejects_a_missing_domain" {
  command = plan

  variables {
    domain_access = {
      network = {
        plan_role_names = ["network-plan"]
      }
    }
  }

  expect_failures = [var.domain_access]
}
