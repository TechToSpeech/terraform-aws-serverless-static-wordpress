resource "aws_efs_file_system" "wordpress_persistent" {
  encrypted = true
  lifecycle_policy {
    transition_to_ia = "AFTER_7_DAYS"
  }
  tags = {
    "Name" = "${var.site_name}_wordpress_persistent"
  }
}

data "aws_iam_policy_document" "ecs_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com", "ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "wordpress_bucket_access" {
  statement {
    actions   = ["s3:ListBucket"]
    effect    = "Allow"
    resources = [module.cloudfront.wordpress_bucket_arn]
  }
  statement {
    actions   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
    effect    = "Allow"
    resources = ["${module.cloudfront.wordpress_bucket_arn}/*"]
  }
  statement {
    actions   = ["ec2:DescribeNetworkInterfaces"]
    effect    = "Allow"
    resources = ["*"]
  }
  statement {
    actions   = ["route53:ChangeResourceRecordSets"]
    effect    = "Allow"
    resources = ["arn:aws:route53:::hostedzone/${var.hosted_zone_id}"]
  }
}

resource "aws_iam_policy" "wordpress_bucket_access" {
  name        = "${var.site_name}_WordpressBucketAccess"
  description = "The role that allows Wordpress task to do necessary operations"
  policy      = data.aws_iam_policy_document.wordpress_bucket_access.json
}

resource "aws_iam_role_policy_attachment" "wordpress_bucket_access" {
  role       = aws_iam_role.wordpress_task.name
  policy_arn = aws_iam_policy.wordpress_bucket_access.arn
}

resource "aws_iam_role" "wordpress_task" {
  name               = "${var.site_name}_WordpressTaskRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "wordpress_role_attachment_ecs" {
  role       = aws_iam_role.wordpress_task.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "wordpress_role_attachment_cloudwatch" {
  role       = aws_iam_role.wordpress_task.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_efs_access_point" "wordpress_efs" {
  file_system_id = aws_efs_file_system.wordpress_persistent.id
}

resource "aws_security_group" "efs_security_group" {
  name        = "${var.site_name}_efs_sg"
  description = "security group for wordpress"
  vpc_id      = var.main_vpc_id
}

resource "aws_security_group_rule" "efs_ingress" {
  security_group_id        = aws_security_group.efs_security_group.id
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "TCP"
  source_security_group_id = aws_security_group.wordpress_security_group.id
  description              = "Ingress to EFS mount from Wordpress container"
}

resource "aws_efs_mount_target" "wordpress_efs" {
  for_each        = toset(var.subnet_ids)
  file_system_id  = aws_efs_file_system.wordpress_persistent.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs_security_group.id]
}

#tfsec:ignore:AWS089
resource "aws_cloudwatch_log_group" "wordpress_container" {
  name              = "/aws/ecs/${var.site_name}-serverless-wordpress-container"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "wordpress_container" {
  family = "${var.site_name}_wordpress"
  container_definitions = templatefile("${path.module}/task-definitions/wordpress.json", {
    db_host                  = aws_rds_cluster.serverless_wordpress.endpoint,
    db_user                  = aws_rds_cluster.serverless_wordpress.master_username,
    db_password              = random_password.serverless_wordpress_password.result,
    db_name                  = aws_rds_cluster.serverless_wordpress.database_name,
    wordpress_image          = "${aws_ecr_repository.serverless_wordpress.repository_url}:latest",
    wp_dest                  = "https://${var.site_prefix}.${var.site_domain}",
    wp_region                = var.s3_region,
    wp_bucket                = module.cloudfront.wordpress_bucket_id,
    container_dns            = "${var.wordpress_subdomain}.${var.site_domain}",
    container_dns_zone       = var.hosted_zone_id,
    container_cpu            = var.ecs_cpu,
    container_memory         = var.ecs_memory
    efs_source_volume        = "${var.site_name}_wordpress_persistent"
    wordpress_admin_user     = var.wordpress_admin_user
    wordpress_admin_password = var.wordpress_admin_password
    wordpress_admin_email    = var.wordpress_admin_email
    site_name                = var.site_name
  })

  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.wordpress_task.arn
  task_role_arn            = aws_iam_role.wordpress_task.arn

  volume {
    name = "${var.site_name}_wordpress_persistent"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.wordpress_persistent.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.wordpress_efs.id
      }
    }

  }
  tags = {
    "Name" = "${var.site_name}_WordpressECS"
  }

  depends_on = [
    aws_efs_file_system.wordpress_persistent
  ]
}

resource "aws_security_group" "wordpress_security_group" {
  name        = "${var.site_name}_wordpress_sg"
  description = "security group for wordpress"
  vpc_id      = var.main_vpc_id
}

resource "aws_security_group_rule" "wordpress_sg_ingress_80" {
  security_group_id = aws_security_group.wordpress_security_group.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "TCP"
  #tfsec:ignore:AWS006
  cidr_blocks = ["0.0.0.0/0"]
  description = "Allow ingress from world to Wordpress container"
}

resource "aws_security_group_rule" "wordpress_sg_egress_2049" {
  security_group_id        = aws_security_group.wordpress_security_group.id
  source_security_group_id = aws_security_group.efs_security_group.id
  type                     = "egress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "TCP"
  description              = "Egress to EFS mount from Wordpress container"
}

resource "aws_security_group_rule" "wordpress_sg_egress_80" {
  security_group_id = aws_security_group.wordpress_security_group.id
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "TCP"
  #tfsec:ignore:AWS007
  cidr_blocks = ["0.0.0.0/0"]
  description = "Egress from Wordpress container to world on HTTP"
}

resource "aws_security_group_rule" "wordpress_sg_egress_443" {
  security_group_id = aws_security_group.wordpress_security_group.id
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "TCP"
  #tfsec:ignore:AWS007
  cidr_blocks = ["0.0.0.0/0"]
  description = "Egress from Wordpress container to world on HTTPS"
}


resource "aws_security_group_rule" "wordpress_sg_egress_3306" {
  security_group_id        = aws_security_group.wordpress_security_group.id
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "TCP"
  source_security_group_id = aws_security_group.aurora_serverless_group.id
  description              = "Egress from Wordpress container to Aurora Database"
}


resource "aws_ecs_service" "wordpress_service" {
  name            = "${var.site_name}_wordpress"
  task_definition = "${aws_ecs_task_definition.wordpress_container.family}:${aws_ecs_task_definition.wordpress_container.revision}"
  cluster         = aws_ecs_cluster.wordpress_cluster.arn
  desired_count   = var.launch
  # iam_role =
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = "100"
    base              = "1"
  }
  propagate_tags = "SERVICE"
  # Explicitly setting version here: https://stackoverflow.com/questions/62552562/one-or-more-of-the-requested-capabilities-are-not-supported-aws-fargate
  platform_version = "1.4.0"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.wordpress_security_group.id]
    assign_public_ip = true
  }
}

# TODO: Add option to enable container insights
#tfsec:ignore:AWS090
resource "aws_ecs_cluster" "wordpress_cluster" {
  name               = "${var.site_name}_wordpress"
  capacity_providers = ["FARGATE_SPOT"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = "100"
    base              = "1"
  }
}
