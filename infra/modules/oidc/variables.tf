variable "name_prefix" {
  type = string
}

variable "github_repo" {
  type    = string
  default = "Shannus/Shannus.github.io"
}

variable "environment" {
  type = string
}

variable "create_provider" {
  type        = bool
  default     = true
  description = "Create the account-wide GitHub OIDC provider (only once per AWS account)."
}
