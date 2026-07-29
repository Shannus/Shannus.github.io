# Single source of truth for the mandatory multi-tenant naming + tagging convention.
# Every resource name and tag in the stack is derived from here, so the
# [ProductSuite]-[TenantName]-[Environment] structure is enforced, not hoped for.
locals {
  prefix = "${var.product_suite}-${var.tenant}-${var.environment}"

  tags = {
    ProductSuite = var.product_suite
    Tenant       = var.tenant
    Environment  = var.environment
    ManagedBy    = "terraform"
    Repo         = "Shannus/Shannus.github.io"
  }
}
