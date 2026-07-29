variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "product_suite" {
  type    = string
  default = "portfolio"
}

variable "tenant" {
  type    = string
  default = "public"
}

variable "environment" {
  type = string # dev | stage | prod (from *.tfvars)
}

variable "github_repo" {
  type    = string
  default = "Shannus/Shannus.github.io"
}

variable "create_oidc_provider" {
  type        = bool
  default     = true
  description = "Set true the FIRST time only (creates the account-wide GitHub OIDC provider)."
}

variable "cors_allow_origins" {
  type    = list(string)
  default = ["https://shannus.github.io"]
}
