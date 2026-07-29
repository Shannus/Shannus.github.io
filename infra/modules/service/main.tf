locals {
  function_name = "${var.name_prefix}-${var.service}"
  needs_secret  = var.db_secret_arn != ""
}

# --- Placeholder artifact so infra can stand up before the first CI deploy. ---
# Terraform owns the function *skeleton*; the GitHub Actions pipeline owns code
# deploys (UpdateFunctionCode -> PublishVersion -> move alias). lifecycle.ignore_changes
# below prevents TF from fighting the pipeline over code/version.
data "archive_file" "placeholder" {
  type                    = "zip"
  output_path             = "${path.module}/.placeholder-${var.service}.zip"
  source_content          = "exports.handler = async () => ({ statusCode: 200, body: JSON.stringify({ status: \"bootstrapping\" }) });"
  source_content_filename = "index.js"
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
}

# --- Execution role ---
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "exec" {
  name               = "${local.function_name}-exec"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc" {
  count      = var.vpc_config == null ? 0 : 1
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "secret" {
  count = local.needs_secret ? 1 : 0
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.db_secret_arn]
  }
}

resource "aws_iam_role_policy" "secret" {
  count  = local.needs_secret ? 1 : 0
  name   = "${local.function_name}-read-db-secret"
  role   = aws_iam_role.exec.id
  policy = data.aws_iam_policy_document.secret[0].json
}

# --- Function (publish=true => every code change mints an immutable version) ---
resource "aws_lambda_function" "this" {
  function_name    = local.function_name
  role             = aws_iam_role.exec.arn
  runtime          = var.runtime
  handler          = var.handler
  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256
  memory_size      = var.memory_mb
  timeout          = var.timeout_s
  publish          = true

  environment {
    variables = var.environment_vars
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config == null ? [] : [var.vpc_config]
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  lifecycle {
    # CI owns code + published versions after bootstrap; do not let TF revert them.
    ignore_changes = [filename, source_code_hash]
  }

  depends_on = [aws_cloudwatch_log_group.this]
}

# --- Alias: the stable, movable pointer API Gateway invokes. "live" = current prod version. ---
resource "aws_lambda_alias" "live" {
  name             = "live"
  function_name    = aws_lambda_function.this.function_name
  function_version = aws_lambda_function.this.version

  lifecycle {
    # The pipeline shifts this alias (canary weight -> 100%, or rollback). Don't fight it.
    ignore_changes = [function_version, routing_config]
  }
}

# --- API Gateway integration + route target the ALIAS, so traffic follows versioned deploys. ---
resource "aws_apigatewayv2_integration" "this" {
  api_id                 = var.api_id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_alias.live.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "this" {
  api_id    = var.api_id
  route_key = var.route_key
  target    = "integrations/${aws_apigatewayv2_integration.this.id}"
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGWInvokeAlias"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  qualifier     = aws_lambda_alias.live.name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_execution_arn}/*/*"
}
