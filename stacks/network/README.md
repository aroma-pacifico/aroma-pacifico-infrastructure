# Network root and single-center association

`variables.tf` preserves B03's environment/Region/tag inputs plus the single approved center selection. The catalog maps Cauca to `10.41.0.0/16`, Huila to `10.42.0.0/16`, and Tolima to `10.43.0.0/16`. Permanent associations target pdn; dev is isolated, and B07 owns any explicitly approved temporary QA logistics path. No all-center or Buenaventura connection is created.

The complete resource composition is in [association-template](association-template/README.md). Verify it with `python scripts/verify-d05.py --module-root <local-collection-center-association-directory>`. The module stays in the public modules repository. This root's selection-only native tests remain useful validation evidence but have zero resources and are not the connection acceptance evidence.

See [final plan-only delivery evidence](../../docs/b05-final-delivery.md) for resource counts, security results, acceptance and remaining release contracts. The existing S3 backend declaration is never initialized during offline validation.
