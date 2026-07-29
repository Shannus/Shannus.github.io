output "api_base_url" { value = aws_apigatewayv2_stage.default.invoke_url }
output "contact_endpoint" { value = "${aws_apigatewayv2_stage.default.invoke_url}contact" }
output "status_endpoint" { value = "${aws_apigatewayv2_stage.default.invoke_url}status" }
output "gha_deploy_role_arn" { value = module.oidc.deploy_role_arn }
output "contact_function_name" { value = module.contact.function_name }
output "status_function_name" { value = module.status.function_name }
output "db_secret_arn" { value = module.database.db_secret_arn }
output "db_host" { value = module.database.db_host }
