locals {
  # A11 section 2 and A07 section 2; catalog entries are configuration, not instances.
  collection_centers = {
    cauca  = { department = "cauca", cidr_block = "10.41.0.0/16" }
    huila  = { department = "huila", cidr_block = "10.42.0.0/16" }
    tolima = { department = "tolima", cidr_block = "10.43.0.0/16" }
  }

  # Unknown selections remain null while input validation emits its diagnostic.
  selected_center = try(merge(local.collection_centers[var.collection_center.key], {
    key         = var.collection_center.key
    environment = var.environment
  }), null)

  # Governance prefix <client>-<project>-<environment>-cc, at most 20 characters (module contract).
  association_name_prefix = lower("${var.common_tags.Client}-${var.common_tags.Project}-${var.environment}-cc")
}
