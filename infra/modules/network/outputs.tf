output "vpc_id" { value = aws_vpc.this.id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }
output "lambda_sg_id" { value = aws_security_group.lambda.id }
output "db_sg_id" { value = aws_security_group.db.id }
output "db_subnet_group" { value = aws_db_subnet_group.this.name }
