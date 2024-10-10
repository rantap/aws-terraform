provider "aws" {
  region = "eu-north-1"
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy_attachment" "lambda_policy_attachment" {
  name       = "lambda_policy_attachment"
  roles      = [aws_iam_role.lambda_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "appsync_resolver_lambda" {
  function_name = "AppSyncResolverLambda"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_execution_role.arn

  filename      = "lambdas/lambda_function_payload.zip"  # Pre-packaged zip of your Lambda function code

  source_code_hash = filebase64sha256("lambdas/lambda_function_payload.zip")  # Ensure Terraform redeploys on code changes
}

resource "aws_appsync_graphql_api" "example" {
  name = "MyAppSyncAPI"
  authentication_type = "API_KEY"

  schema = file("schema.graphql")
}

resource "aws_appsync_api_key" "example" {
  api_id      = aws_appsync_graphql_api.example.id
  expires     = timeadd(timestamp(), "24h")
}

resource "aws_appsync_datasource" "lambda_datasource" {
  api_id           = aws_appsync_graphql_api.example.id
  name             = "LambdaDataSource"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.lambda_execution_role.arn

  lambda_config {
    function_arn = aws_lambda_function.appsync_resolver_lambda.arn
  }
}

resource "aws_appsync_resolver" "hello_query" {
  api_id      = aws_appsync_graphql_api.example.id
  type        = "Query"
  field       = "hello"
  data_source = aws_appsync_datasource.lambda_datasource.name
}