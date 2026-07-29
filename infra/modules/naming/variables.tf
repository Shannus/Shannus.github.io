variable "product_suite" {
  type        = string
  description = "Product suite segment of the mandatory naming structure."
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,15}$", var.product_suite))
    error_message = "product_suite must be lowercase alphanumeric, starting with a letter (2-16 chars)."
  }
}

variable "tenant" {
  type        = string
  description = "Tenant segment. Each tenant is logically isolated (own schema, own resource names)."
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,20}$", var.tenant))
    error_message = "tenant must be lowercase alphanumeric, starting with a letter (2-21 chars)."
  }
}

variable "environment" {
  type        = string
  description = "Environment segment."
  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "environment must be one of: dev, stage, prod."
  }
}
