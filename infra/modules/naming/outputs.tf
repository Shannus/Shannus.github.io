output "prefix" {
  value       = local.prefix
  description = "Naming prefix: <product_suite>-<tenant>-<environment>."
}

output "tags" {
  value       = local.tags
  description = "Mandatory compliance tag set applied to every resource via provider default_tags."
}
