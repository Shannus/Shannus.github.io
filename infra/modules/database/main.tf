# Generated master password — never stored in code or state output; kept in Secrets Manager.
resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_db_instance" "this" {
  identifier              = "${var.name_prefix}-pg"
  engine                  = "postgres"
  engine_version          = var.engine_version
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  storage_type            = "gp3"
  storage_encrypted       = true
  db_name                 = var.db_name
  username                = "portfolio_admin"
  password                = random_password.db.result
  db_subnet_group_name    = var.db_subnet_group
  vpc_security_group_ids  = [var.db_sg_id]
  publicly_accessible     = false
  multi_az                = false
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 1
  apply_immediately       = true
}

# Database access controls: credentials live only in Secrets Manager.
# The contact Lambda's execution role is granted GetSecretValue on this ARN (see service module).
resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.name_prefix}/db"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = aws_db_instance.this.username
    password = random_password.db.result
    host     = aws_db_instance.this.address
    dbname   = var.db_name
    port     = 5432
  })
}
