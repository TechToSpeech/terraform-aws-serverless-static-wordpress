data "archive_file" "lambda_slack" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_slack/function"
  output_path = "${path.module}/lambda_slack/dst/lambda_slack.zip"
}

# resource "aws_security_group" "lambda_slack_security_group" {
#   name = "lamba_slack_sg"
#   description = "security group for Lamba Slack"
#   vpc_id = var.main_vpc_id

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

#tfsec:ignore:AWS089
resource "aws_cloudwatch_log_group" "lambda_slack" {
  name              = "/aws/lambda/${var.site_name}_lambda_slack"
  retention_in_days = 7
}

resource "aws_lambda_function" "lambda_slack" {
  filename         = data.archive_file.lambda_slack.output_path
  function_name    = "${var.site_name}_lambda_slack"
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda_slack.output_base64sha256
  runtime          = "python3.8"
  environment {
    variables = {
      HOOK_URL = var.slack_webhook
    }
  }
  publish     = true
  memory_size = 128
  timeout     = 3
  # vpc_config {
  #   subnet_ids = var.subnet_ids
  #   security_group_ids = [ aws_security_group.lambda_slack_security_group.id ]
  # }
  depends_on = [aws_cloudwatch_log_group.lambda_slack]
}

data "aws_iam_policy_document" "lambda-service-role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.site_name}-lambda-service-role"
  assume_role_policy = data.aws_iam_policy_document.lambda-service-role.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "lambda-cloudwatch-logs" {
  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role_policy" "lambda-cloudwatch-logs" {
  name   = "${var.site_name}-lambda-cloudwatch-logs"
  role   = aws_iam_role.lambda.name
  policy = data.aws_iam_policy_document.lambda-cloudwatch-logs.json
}

resource "aws_cloudwatch_event_rule" "ecs_wordpress_task_state" {
  name        = "${var.site_name}-ecs-wordpress-task-state"
  description = "Event on Wordpress ECS Task State"

  event_pattern = jsonencode(
    {
      "source" : [
        "aws.ecs"
      ],
      "detail-type" : [
        "ECS Task State Change"
      ],
      "detail" : {
        "clusterArn" : [
          var.ecs_cluster_arn
        ]
      }
    }
  )
}

resource "aws_cloudwatch_event_rule" "ecs_wordpress_instance_state" {
  name        = "${var.site_name}-ecs-wordpress-instance-state"
  description = "Event on Wordpress ECS Instance State"

  event_pattern = jsonencode(
    {
      "source" : [
        "aws.ecs"
      ],
      "detail-type" : [
        "ECS Container Instance State Change"
      ],
      "detail" : {
        "clusterArn" : [
          var.ecs_cluster_arn
        ]
      }
    }
  )
}

# resource "aws_cloudwatch_event_rule" "ecs_wordpress_service_action" {
#   name        = "ecs-wordpress-service-action"
#   description = "Event on Wordpress ECS Service Action"

#   event_pattern = jsonencode(
# {
#   "source": [
#     "aws.ecs"
#   ],
#   "detail-type": [
#     "ECS Service Action"
#   ],
#   "detail": {
#     "clusterArn": [
#       aws_ecs_cluster.wordpress_cluster.arn
#     ]
#   }
# }
# )
# }

resource "aws_cloudwatch_event_rule" "ecs_wordpress_service_deployment_state" {
  name        = "${var.site_name}-ecs-wordpress-deployment-state"
  description = "Event on Wordpress ECS Deployment State"

  event_pattern = jsonencode(
    {
      "source" : [
        "aws.ecs"
      ],
      "detail-type" : [
        "ECS Deployment State Change"
      ]
    }
  )
}

resource "aws_cloudwatch_event_rule" "rds_wordpress_cluster_state" {
  name        = "${var.site_name}-rds-wordpress-cluster-state"
  description = "Event on Wordpress RDS cluster State"

  event_pattern = jsonencode(
    {
      "source" : [
        "aws.rds"
      ],
      "detail-type" : [
        "RDS DB Cluster Event"
      ]
    }
  )
}

resource "aws_cloudwatch_event_target" "lambda_slack_task_state" {
  arn  = aws_lambda_function.lambda_slack.arn
  rule = aws_cloudwatch_event_rule.ecs_wordpress_task_state.id
}

# resource "aws_cloudwatch_event_target" "lambda_slack_service_action" {
#   arn  = aws_lambda_function.lambda_slack.arn
#   rule = aws_cloudwatch_event_rule.ecs_wordpress_service_action.id
# }

resource "aws_cloudwatch_event_target" "lambda_slack_instance_state" {
  arn  = aws_lambda_function.lambda_slack.arn
  rule = aws_cloudwatch_event_rule.ecs_wordpress_instance_state.id
}

resource "aws_cloudwatch_event_target" "lambda_slack_deployment_state" {
  arn  = aws_lambda_function.lambda_slack.arn
  rule = aws_cloudwatch_event_rule.ecs_wordpress_service_deployment_state.id
}

resource "aws_cloudwatch_event_target" "lambda_slack_cluster_state" {
  arn  = aws_lambda_function.lambda_slack.arn
  rule = aws_cloudwatch_event_rule.rds_wordpress_cluster_state.id
}

resource "aws_lambda_permission" "allow_rule_task_state" {
  statement_id  = "AllowExecutionFromECSTaskState"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_slack.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ecs_wordpress_task_state.arn
}

# resource "aws_lambda_permission" "allow_rule_service_action" {
#   statement_id  = "AllowExecutionFromECSServiceAction"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.lambda_slack.function_name
#   principal     = "events.amazonaws.com"
#   source_arn    = aws_cloudwatch_event_rule.ecs_wordpress_service_action.arn
# }

resource "aws_lambda_permission" "allow_rule_instance_state" {
  statement_id  = "AllowExecutionFromECSInstanceState"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_slack.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ecs_wordpress_instance_state.arn
}

resource "aws_lambda_permission" "allow_rule_deployment_state" {
  statement_id  = "AllowExecutionFromECSDeploymentState"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_slack.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ecs_wordpress_service_deployment_state.arn
}

resource "aws_lambda_permission" "allow_rule_cluster_state" {
  statement_id  = "AllowExecutionFromRDSClusterState"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_slack.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.rds_wordpress_cluster_state.arn
}
