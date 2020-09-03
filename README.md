# modernisation-platform-terraform-iam-superadmins

This repository holds a Terraform module that creates set IAM accounts and associated configuration, such as: account password policies, administrator groups, user accounts.

## Usage
```
  module "iam" {
    source        = "github.com/ministryofjustice/modernisation-platform-terraform-iam-superadmins"
    account_alias = "aws-account-alias"
  }
```

## Inputs
|      Name     |               Description              |  Type  | Default | Required |
|:-------------:|:--------------------------------------:|:------:|:-------:|----------|
| account_alias | AWS IAM account alias for this account | string | n/a     | yes      |
