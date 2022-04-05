# Changelog

## 0.2.0 - UNRELEASED

! BREAKING CHANGES ! - See [UPGRADING.md](docs/UPGRADING.md) for guidance on upgrading from v0.1.x

 ### **Maintenance**:

 - Module upgraded to AWS Terraform v4. Existing installations will need Terraform state moved for forwards
compatibility.

### **New Features**
- Added support for Graviton-based CodeBuild if supported in deployment region. Will gracefully fallback to
non-Graviton if not supported.
- Added support for Graviton-based ECS Fargate if supported in deployment region. Will fallback to non-Graviton
if not supported, however source docker image used for ECS container MUST be AMD64/ARM64 architecture respectively.
Note FARGATE_SPOT is not supported for Graviton-based ECS at this time.
- Added healthCheeck block to ECS Task Definition.
- Added EventBridge monitoring for ECS Service Action events (which captures placement failures when using FARGATE_SPOT
 capacity provider)

## 0.1.2 - 23rd June 2021

- **Bugfix**: Changed special characters used in RDS password generation to ensure compatibility.
- **Docs**: Updated to fix typos in helper commands, and detailed supported RDS Aurora v1 regions.

## 0.1.1 - 19th June 2021

- **Bugfix**: Refactor md5 calculation on archive_file in codebuild child module.
- **Bugfix**: Re-typed AWS account number as string to avoid rounding on account numbers prepended with zeros.
-- **Bugfix**: Fix passed WAF variable values if set to inactive.

## 0.1.0 - 19th June 2021

- Initial release of Serverless Static Wordpress Terraform module.
