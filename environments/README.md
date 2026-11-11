# Environment variable files guide

This directory contains example `.tfvars` files for each environment.

## How to use

1. Copy the example file for the target environment:
   ```bash
   cp environments/dev.tfvars.example environments/dev.tfvars
   ```
2. Edit non-sensitive variables as needed (e.g., `region`).
3. Provide sensitive values via environment variables or secret manager:
   ```bash
   export TF_VAR_db_password="super-secret"
   ```
4. Run Terraform with the variable file:
   ```bash
   terraform plan -var-file=environments/dev.tfvars
   ```

Do **not** commit any `.tfvars` files containing secrets. The examples contain only placeholders.
