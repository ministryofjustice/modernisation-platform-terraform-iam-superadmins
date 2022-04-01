# Modernisation Platform Terraform IAM Superadmins Module
[![repo standards badge](https://img.shields.io/badge/dynamic/json?color=blue&style=for-the-badge&logo=github&label=MoJ%20Compliant&query=%24.data%5B%3F%28%40.name%20%3D%3D%20%22modernisation-platform-terraform-iam-superadmins%22%29%5D.status&url=https%3A%2F%2Foperations-engineering-reports.cloud-platform.service.justice.gov.uk%2Fgithub_repositories)](https://operations-engineering-reports.cloud-platform.service.justice.gov.uk/github_repositories#modernisation-platform-terraform-iam-superadmins "Link to report")

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

## Outputs
| Name                 | Description                                                      | Sensitive |
|----------------------|------------------------------------------------------------------|-----------|
| superadmin_passwords | PGP-encrypted passwords for IAM users, if a pgp_key is specified | no        |

## First-sign in and changing a password
The included force_mfa IAM policy doesn't allow a user to change their password without MFA enabled. When onboarding a new superadmin,
they will need to configure MFA before logging in for the first time.

## Looking for issues?
If you're looking to raise an issue with this module, please create a new issue in the [Modernisation Platform repository](https://github.com/ministryofjustice/modernisation-platform/issues).
