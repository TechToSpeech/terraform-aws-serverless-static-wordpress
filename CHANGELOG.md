# Changelog

## 0.1.2 - 23rd June 2021

Bugfix: Changed special characters used in RDS password generation to ensure compatibility.
Docs: Updated to fix typos in helper commands, and detailed supported RDS Aurora v1 regions.

## 0.1.1 - 19th June 2021

Bugfix: Refactor md5 calculation on archive_file in codebuild child module.
Bugfix: Re-typed AWS account number as string to avoid rounding on account numbers prepended with zeros.
Bugfix: Fix passed WAF variable values if set to inactive.

## 0.1.0 - 19th June 2021

Initial release of Serverless Static Wordpress Terraform module.
