variable "name_prefix" {
  type = string
}

variable "service" {
  type = string # e.g. "contact" or "status"
}

variable "handler" {
  type    = string
  default = "index.handler"
}

variable "runtime" {
  type    = string
  default = "nodejs22.x"
}

variable "memory_mb" {
  type    = number
  default = 256
}

variable "timeout_s" {
  type    = number
  default = 10
}

variable "api_id" {
  type = string
}

variable "api_execution_arn" {
  type = string
}

variable "route_key" {
  type = string # e.g. "POST /contact"
}

variable "environment_vars" {
  type    = map(string)
  default = {}
}

variable "db_secret_arn" {
  type    = string
  default = "" # empty => no secret access
}

variable "vpc_config" {
  type    = object({ subnet_ids = list(string), security_group_ids = list(string) })
  default = null # null => function runs outside the VPC
}

variable "log_retention_days" {
  type    = number
  default = 14
}
