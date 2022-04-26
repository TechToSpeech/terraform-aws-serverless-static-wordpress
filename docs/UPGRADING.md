## Upgrading from 0.1.x to 0.2.x

Version 0.2 of Serverless Static Wordpress makes numerous updates to the resources used to deploy the solution, as well
as expanding functionality with additional options.

Where possible, this has been done in a way to be as backwards compatible as reasonably possible - however there are a
variety of quirks of Terraform behaviour that can mean that this is imperfect, and may require a manual tweak either to
the configuration in AWS, or to the Terraform state backing the resources.

### Upgrading to Version 4 of the Terraform AWS Provider
Version 4 of the AWS Provider introduced a few breaking changes to the way ECS and S3 resources are defined. Attributes
that would normally be specified as part of the single resource definition have now been split out into their own
resources. To cope with this, we have created these resources, and _existing_ resources can be handled with some
terraform state operations. To date, these are documented as follows.

NOTE, in these examples, the example `site_name` is `peterdotcloud` and the resources are named accordingly. You will
need to substitute these values with the value used for your own deployment

```
terraform import module.peterdotcloud_website.aws_ecs_cluster_capacity_providers.wordpress_cluster peterdotcloud_wordpress
terraform state rm module.peterdotcloud_website.module.codebuild.aws_s3_bucket_object.wordpress_dockerbuild
terraform import module.peterdotcloud_website.module.codebuild.aws_s3_object.wordpress_dockerbuild peterdotcloud-build/wordpress_docker.zip
terraform import module.peterdotcloud_website.module.cloudfront.aws_s3_bucket_server_side_encryption_configuration.wordpress_bucket www.peter.cloud
terraform import module.peterdotcloud_website.module.codebuild.aws_s3_bucket_acl.code_source peterdotcloud-build
terraform import module.peterdotcloud_website.module.codebuild.aws_s3_bucket_server_side_encryption_configuration.code_source peterdotcloud-build
```
### Graviton

With support for ARM in CodeBuild, and in ECS in regions where it is supported (strictly better for cost/performance),
the module will need to recreate your task definition and ECS service. This is nothing to be concerned with however you
 **must** ensure your base image of Wordpress is an arm64 platform version (and preferably linux/arm64/v8) otherwise
 your Wordpress container will error out with `exec user process caused: exec format error` which indicates your image
 is of the mismatched architecture.

 Note that when using Graviton-based containers for ECS, FARGATE_SPOT is not currently available (bear this in mind for
 cost).