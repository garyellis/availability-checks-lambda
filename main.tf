data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name = var.name_prefix == "" ? "availability-checks-lambda" : format("%s-availability-checks-lambda", var.name_prefix)
}

data "aws_iam_policy_document" "trust_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers =  ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "permission_policy" {
  statement {
    sid     = "CloudWatchLogGroup"
    effect  = "Allow"
    actions = [
      "logs:CreateLogGroup",
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
    ]
   }

  statement {
    sid     = "CloudWatchLogStream"
    effect  = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
   resources = [
     "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.name}:*"
   ]
  }

  statement {
    sid     = "LambdaInVpc"
    effect  = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:AttachNetworkInterface"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "WriteCloudWatchMetricAlarms"
    effect  = "Allow"
    actions = [
      "cloudwatch:PutMetricData",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DeleteMetricAlarm"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "ReadConfigFromDynamodb"
    effect  = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:Query",
      "dynamodb:Scan" 
    ]
    resources = [
      "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${local.name}"
    ]
  }
}

resource "aws_iam_policy" "iam_policy" {
  name_prefix = local.name
  policy = data.aws_iam_policy_document.permission_policy.json
}

resource "aws_iam_role" "iam_role" {
  name_prefix        = local.name
  description        = "aws config custom metrics"
  assume_role_policy = data.aws_iam_policy_document.trust_policy.json
}

resource "aws_iam_role_policy_attachment" "iam_role" {
  role       = aws_iam_role.iam_role.name
  policy_arn = aws_iam_policy.iam_policy.arn
}

resource "null_resource" "package_zip" {
  triggers = {
    main = base64sha256(file("${path.module}/lambda/main.py"))
  }
}

data "archive_file" "main" {
  type        = "zip"
  source_file  = "${path.module}/lambda/main.py"
  output_path = "${path.module}/lambda/function.zip"

  depends_on = [null_resource.package_zip]
}

resource "aws_lambda_function" "lambda" {
  filename         = data.archive_file.main.output_path
  source_code_hash = data.archive_file.main.output_base64sha256
  function_name    = local.name
  role             = aws_iam_role.iam_role.arn
  handler          = "main.lambda_handler"
  runtime          = "python3.7"
  timeout          = 900
  tags             = merge(map("Name", local.name), var.tags)
  environment {
    variables = merge(var.environment,
      {
        ALARM_ARNS         = var.alarm_arns
        DYNAMODB_TABLE     = aws_dynamodb_table.lambda_config.id
        DYNAMODB_CONFIG_ID = local.name
      }
    )
  }

  dynamic "vpc_config" {
    for_each = var.subnet_ids != null && var.security_group_ids != null ? [true] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }   
  }
}

### event triggers
resource "aws_cloudwatch_event_rule" "lambda_cron" {
  name_prefix         = local.name
  description         = ""
  is_enabled          = true
  schedule_expression = "rate(5 minutes)"
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.lambda_cron.name
  target_id = "configrules-cloudwatch-lambda"
  arn       = aws_lambda_function.lambda.arn
}

resource "aws_lambda_permission" "lambda" {
  statement_id  = local.name
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_cron.arn
}


#### external configuration
resource "aws_dynamodb_table" "lambda_config" {
  name           = local.name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "configId"
  range_key      = "target"

  attribute {
    name = "configId"
    type = "S"
  }

  attribute {
    name = "target"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "example" {
  count = length(var.config)

  table_name = aws_dynamodb_table.lambda_config.name
  hash_key   = aws_dynamodb_table.lambda_config.hash_key
  range_key  = aws_dynamodb_table.lambda_config.range_key

  item = <<ITEM
{
  "configId":     {"S": "${local.name}" },
  "target":       {"S": "${lookup(var.config[count.index], "target")}" },
  "type":         {"S": "${lookup(var.config[count.index], "type")}" },
  "host":         {"S": "${lookup(var.config[count.index], "host")}" },
  "port":         {"S": "${lookup(var.config[count.index], "port")}" }
}
ITEM
}
