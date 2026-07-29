module "naming" {
  source        = "./modules/naming"
  product_suite = var.product_suite
  tenant        = var.tenant
  environment   = var.environment
}

provider "aws" {
  region = var.aws_region
  # Every resource inherits the mandatory compliance tag set automatically.
  default_tags {
    tags = module.naming.tags
  }
}

module "network" {
  source      = "./modules/network"
  name_prefix = module.naming.prefix
}

module "database" {
  source          = "./modules/database"
  name_prefix     = module.naming.prefix
  db_subnet_group = module.network.db_subnet_group
  db_sg_id        = module.network.db_sg_id
}

module "oidc" {
  source          = "./modules/oidc"
  name_prefix     = module.naming.prefix
  github_repo     = var.github_repo
  environment     = var.environment
  create_provider = var.create_oidc_provider
}

# --- One HTTP API fronts both product lines (V1 contact + V2 status). ---
resource "aws_apigatewayv2_api" "this" {
  name          = "${module.naming.prefix}-api"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = var.cors_allow_origins
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true
}

# --- V1 product line: contact (in-VPC, DB-backed) ---
module "contact" {
  source            = "./modules/service"
  name_prefix       = module.naming.prefix
  service           = "contact"
  api_id            = aws_apigatewayv2_api.this.id
  api_execution_arn = aws_apigatewayv2_api.this.execution_arn
  route_key         = "POST /contact"
  db_secret_arn     = module.database.db_secret_arn
  vpc_config = {
    subnet_ids         = module.network.private_subnet_ids
    security_group_ids = [module.network.lambda_sg_id]
  }
  environment_vars = {
    PRODUCT_SUITE = var.product_suite
    TENANT        = var.tenant
    ENVIRONMENT   = var.environment
    DB_SECRET_ARN = module.database.db_secret_arn
    DB_HOST       = module.database.db_host
    DB_NAME       = module.database.db_name
  }
}

# --- V2 product line: status (outside VPC, no DB) ---
module "status" {
  source            = "./modules/service"
  name_prefix       = module.naming.prefix
  service           = "status"
  api_id            = aws_apigatewayv2_api.this.id
  api_execution_arn = aws_apigatewayv2_api.this.execution_arn
  route_key         = "GET /status"
  environment_vars = {
    PRODUCT_SUITE = var.product_suite
    TENANT        = var.tenant
    ENVIRONMENT   = var.environment
  }
}
