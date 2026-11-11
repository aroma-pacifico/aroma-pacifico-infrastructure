# Per-environment variables and secrets

This directory separates the configuration of the three environments, `dev`,
`qa` and `pdn` (ASM-006), and states how secrets stay out of the repository
and out of the state (B03, box D03, ADR-003). Production (`pdn`) and test (`qa`
and `dev`) never share a variable file, a state bucket or a credential.

```text
environments/
|-- .gitignore             ignores real *.tfvars and *.tfbackend; only *.example is tracked
|-- dev/dev.tfvars.example
|-- qa/qa.tfvars.example
`-- pdn/pdn.tfvars.example
```

Each example holds only non-sensitive inputs, the same three for every stack:
`aws_region`, `environment` and `common_tags` (Client, Project, Environment,
Owner, CostCenter). The Region is `us-east-1` for every environment (ADR-001).
The `Client` and `Project` values are still pending decision PD-070, so the
examples carry placeholders. Backend files are not kept here: each stack owns
its `backends/<env>.s3.tfbackend.example` (B02).

## Usage

Run from the repository root, with the environment code in `ENV` and the stack
name in `STACK`.

```bash
ENV=dev
STACK=network

# 1. Create the real, untracked variable file from the example.
cp environments/$ENV/$ENV.tfvars.example environments/$ENV/$ENV.tfvars

# 2. Replace the placeholders. Non-sensitive values only.

# 3. Initialize against the backend file of that environment (B02), then plan.
terraform -chdir=stacks/$STACK init -backend-config=backends/$ENV.s3.tfbackend
terraform -chdir=stacks/$STACK plan -var-file=../../environments/$ENV/$ENV.tfvars
```

The work is plan-only: nothing here runs `terraform apply` or `terraform destroy`.
Promotion is `dev`, then `qa`, then `pdn` with the same module tags; an
environment differs only by its variable file and its backend file.

## Secrets: injected from outside, never stored

The pattern needs no secret today (ADR-003): CI reaches AWS through GitHub OIDC
federation, so there is no access key, and the services authorize through IAM
roles, so there is no database password. The rules below apply to any secret a
resource needs later.

| Rule | How |
|---|---|
| No secret in git | `.tfvars`, `.tfbackend` and `terraform.tfvars` hold names and codes only (PC-IAC-002 section 5.3, PC-IAC-016). `environments/.gitignore` blocks real files and `scripts/check-env-secrets.sh` fails on secret-looking content. |
| Injection from an external mechanism | Credentials come from the GitHub Actions environment (`dev`, `qa`, `pdn`) through OIDC role assumption. A value that a variable must carry is supplied as `TF_VAR_<name>` from that environment's secrets, or read from AWS Secrets Manager or an SSM `SecureString`, never from a file. |
| No plaintext in the state | Declare the variable `sensitive = true`. Read the secret with an `ephemeral` resource (Terraform 1.10 or later) and pass it only to a write-only argument (`*_wo` with `*_wo_version`, Terraform 1.11 or later). Neither the plan nor the state stores it. |
| No exposure through outputs or plans | No output returns a secret. Saved plan files are never committed; only the rendered text of a plan reaches a pull request. |

A secret-bearing resource follows this shape. The secret is referenced by name
and read at run time; no value appears in the repository.

```hcl
variable "db_secret_name" {
  type        = string
  description = "Name of the Secrets Manager secret that holds the credential."
}

ephemeral "aws_secretsmanager_secret_version" "db" {
  secret_id = var.db_secret_name
}

resource "aws_ssm_parameter" "example" {
  name             = "/${var.environment}/example"
  type             = "SecureString"
  value_wo         = ephemeral.aws_secretsmanager_secret_version.db.secret_string
  value_wo_version = 1
}
```

Avoid the `aws_secretsmanager_secret_version` data source and the
`random_password` resource for this purpose: both write the value to the state.
The state itself is encrypted with a customer-managed KMS key and reachable only
by the roles of its own environment (B02), which is the second line of defense,
not a license to store a secret in it.

## Verification

```bash
terraform fmt -check -recursive
scripts/check-env-secrets.sh
```

Copy an example to a temporary `.tfvars` and run `terraform plan -var-file=...`
against each stack to confirm the inputs satisfy every variable and validation.
