output "function_name" { value = aws_lambda_function.this.function_name }
output "alias_name" { value = aws_lambda_alias.live.name }
output "alias_arn" { value = aws_lambda_alias.live.arn }
