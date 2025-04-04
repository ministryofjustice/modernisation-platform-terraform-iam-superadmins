# You can define superadmin usernames, and their keybase key if applicable, below, and this will automatically create:
# - their account
# - an attachment to the "superadmins" group, which has the IAM policy of AdministratorAccess, and forced MFA
# - if a keybase key is provided, it will also create their user login profile
locals {
  superadmin_users = {
    "aaron.robinson"   = ""
    "david.elliott"    = "keybase:davidkelliott"
    "david.sibley"     = ""
    "ewa.stempel"      = ""
    "edward.proctor"   = ""
    "khatra.farah"     = ""
    "kudzai.mtoko"     = ""
    "mark.roberts"     = ""
    "mike.reid"        = ""
    "richard.green"    = ""
    "sukesh.reddygade" = ""
  }
}

# Create the initial IAM account referential
module "iam_account" {
  source        = "github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-account?ref=617f4cbaef43e437233468dbeb743acf4069894e" #v5.46.0
  account_alias = var.account_alias

  # We create the password policy as part of `modernisation-platform-terraform-baselines` so
  # we don't need to do it here as well
  create_account_password_policy = false
}

# sleep to allow time for user creation
resource "time_sleep" "wait_30_seconds" {
  depends_on = [module.iam_user]

  create_duration = "30s"

  triggers = {
    for user in module.iam_user : user.iam_user_name => user.iam_user_arn
  }

}

# Create assumable roles with managed policies
module "iam_assumable_roles" {
  source               = "github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-assumable-roles?ref=617f4cbaef43e437233468dbeb743acf4069894e" #v5.46.0
  max_session_duration = 43200

  # Admin role
  create_admin_role       = true
  admin_role_name         = "superadmin"
  admin_role_requires_mfa = true

  # Poweruser role
  create_poweruser_role       = true
  poweruser_role_name         = "developer"
  poweruser_role_requires_mfa = true

  # Read-only role
  create_readonly_role       = true
  readonly_role_name         = "readonly"
  readonly_role_requires_mfa = true

  # Allow created users to assume these roles
  trusted_role_arns = [
    for user in module.iam_user : user.iam_user_arn
  ]

  depends_on = [time_sleep.wait_30_seconds]
}

# Attach created users to a AWS IAM group, with several policies
#tfsec:ignore:aws-iam-enforce-group-mfa
module "iam_group_admins_with_policies" {
  source = "github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-group-with-policies?ref=617f4cbaef43e437233468dbeb743acf4069894e" #v5.46.0
  name   = "superadmins"

  group_users = [
    for user in module.iam_user : user.iam_user_name
  ]

  custom_group_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
  ]

  custom_group_policies = [
    {
      name   = "ForceMFA"
      policy = data.aws_iam_policy_document.force_mfa.json
    },
    {
      name   = "AssumeRole"
      policy = data.aws_iam_policy_document.assume_role.json
    }
  ]
}

# Create each user
module "iam_user" {
  for_each              = local.superadmin_users
  source                = "github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-user?ref=617f4cbaef43e437233468dbeb743acf4069894e" #v5.46.0
  name                  = "${each.key}-superadmin"
  force_destroy         = true
  pgp_key               = each.value
  create_iam_access_key = false

  # The following is dependent on whether a PGP key has been set
  create_iam_user_login_profile = length(each.value) > 0 ? true : false
  password_reset_required       = length(each.value) < 0 ? true : false
}

# Allow users to assume roles if MFA enabled
data "aws_iam_policy_document" "assume_role" {
  statement {
    sid    = "AssumeRole"
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    resources = ["*"]
    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

# AWS IAM Policy Document for Force MFA, as taken from:
# https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_examples_aws_my-sec-creds-self-manage.html
#tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "force_mfa" {
  version = "2012-10-17"

  statement {
    sid    = "AllowViewAccountInfo"
    effect = "Allow"
    actions = [
      "iam:GetAccountPasswordPolicy",
      "iam:GetAccountSummary",
      "iam:ListVirtualMFADevices"
    ]
    resources = ["*"]
  }
  statement {
    sid    = "AllowManageOwnPasswords"
    effect = "Allow"
    actions = [
      "iam:ChangePassword",
      "iam:GetUser"
    ]
    resources = ["arn:aws:iam::*:user/$${aws:username}"]
  }
  statement {
    sid    = "AllowManageOwnAccessKeys"
    effect = "Allow"
    actions = [
      "iam:CreateAccessKey",
      "iam:DeleteAccessKey",
      "iam:ListAccessKeys",
      "iam:UpdateAccessKey"
    ]
    resources = ["arn:aws:iam::*:user/$${aws:username}"]
  }
  statement {
    sid    = "AllowManageOwnSigningCertificates"
    effect = "Allow"
    actions = [
      "iam:DeleteSigningCertificate",
      "iam:ListSigningCertificates",
      "iam:UpdateSigningCertificate",
      "iam:UploadSigningCertificate"
    ]
    resources = ["arn:aws:iam::*:user/$${aws:username}"]
  }
  statement {
    sid    = "AllowManageOwnSSHPublicKeys"
    effect = "Allow"
    actions = [
      "iam:DeleteSSHPublicKey",
      "iam:GetSSHPublicKey",
      "iam:ListSSHPublicKeys",
      "iam:UpdateSSHPublicKey",
      "iam:UploadSSHPublicKey"
    ]
    resources = ["arn:aws:iam::*:user/$${aws:username}"]
  }
  statement {
    sid    = "AllowManageOwnGitCredentials"
    effect = "Allow"
    actions = [
      "iam:CreateServiceSpecificCredential",
      "iam:DeleteServiceSpecificCredential",
      "iam:ListServiceSpecificCredentials",
      "iam:ResetServiceSpecificCredential",
      "iam:UpdateServiceSpecificCredential"
    ]
    resources = ["arn:aws:iam::*:user/$${aws:username}"]
  }
  statement {
    sid    = "AllowManageOwnVirtualMFADevice"
    effect = "Allow"
    actions = [
      "iam:CreateVirtualMFADevice",
      "iam:DeleteVirtualMFADevice"
    ]
    resources = ["arn:aws:iam::*:mfa/$${aws:username}"]
  }
  statement {
    sid    = "AllowManageOwnUserMFA"
    effect = "Allow"
    actions = [
      "iam:DeactivateMFADevice",
      "iam:EnableMFADevice",
      "iam:ListMFADevices",
      "iam:ResyncMFADevice"
    ]
    resources = ["arn:aws:iam::*:user/$${aws:username}"]
  }
  statement {
    sid    = "DenyAllExceptListedIfNoMFA"
    effect = "Deny"
    not_actions = [
      "iam:CreateVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:GetUser",
      "iam:ListMFADevices",
      "iam:ListVirtualMFADevices",
      "iam:ResyncMFADevice",
      "sts:GetSessionToken",
      "iam:ChangePassword"
    ]
    resources = ["*"]
    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["false"]
    }
  }
}
