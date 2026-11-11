# Troubleshooting log

## Floci refused the plan roles of the association providers (B05)

**Symptom:** `terraform plan` of `stacks/network` against the Floci emulator failed in both aliased providers with `Cannot assume IAM Role` and `AccessDenied` on `sts:AssumeRole`.

**Root cause:** The emulator enforces IAM, so a role that was never created cannot be assumed, even with fictitious account `000000000000`.

**Resolution applied:** The `Floci plan` workflow reads the fictitious role ARNs from `stacks/<stack>/emulator.tfvars` and creates each role inside the emulator before the plan. The roles exist only in the throwaway container.

**Preventive architecture:** A stack that adds provider aliases with `assume_role` keeps its fixtures in `emulator.tfvars`; the workflow creates their roles. No real role or account is referenced.

## Secret scan rejected the emulator fixtures (B05)

**Symptom:** `scripts/check-env-secrets.sh` reported an account identifier in `emulator.tfvars`.

**Root cause:** The scanner reports every 12-digit number, including the all-zero account that Floci answers with.

**Resolution applied:** The scanner ignores only `000000000000`, which names no account. Any other 12-digit value is still reported.

**Preventive architecture:** Keep fixtures all-zero so they stay distinguishable from a leaked identifier.
