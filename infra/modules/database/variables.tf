variable "name_prefix" {
  type = string
}

variable "db_subnet_group" {
  type = string
}

variable "db_sg_id" {
  type = string
}

variable "db_name" {
  type    = string
  default = "portfolio"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro" # free-tier eligible
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "engine_version" {
  type    = string
  default = "16" # major-only; RDS selects the latest supported minor
}
