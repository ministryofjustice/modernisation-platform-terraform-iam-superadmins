# You can define superadmin usernames, and their keybase key if applicable, below, and this will automatically create:
# - their account
# - an attachment to the "superadmins" group, which has the IAM policy of AdministratorAccess, and forced MFA
# - if a keybase key is provided, it will also create their user login profile
locals {
  superadmin_users = {
    "david.elliott" = "keybase:davidkelliott"
    "jake.mulley"   = ""
    "phil.horrocks" = ""
  }
}

# Create the initial IAM account referential
module "iam_account" {
  source        = "terraform-aws-modules/iam/aws//modules/iam-account"
  version       = "~> 2.0"
  account_alias = var.account_alias
  # Password policy rules
  allow_users_to_change_password = true
  create_account_password_policy = true
  get_caller_identity            = true
  hard_expiry                    = false
  max_password_age               = 0
  minimum_password_length        = 8
  password_reuse_prevention      = 5
  require_lowercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  require_uppercase_characters   = true
}

# Create assumable roles with managed policies
module "iam_assumable_roles" {
  source               = "terraform-aws-modules/iam/aws//modules/iam-assumable-roles"
  version              = "~> 2.0"
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
    for superadmin in keys(local.superadmin_users) : module.iam_user[superadmin].this_iam_user_arn
  ]
}

# Attach created users to a AWS IAM group, with several policies
module "iam_group_admins_with_policies" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-policies"
  version = "~> 2.0"
  name    = "superadmins"

  group_users = [
    for superadmin in keys(local.superadmin_users) : module.iam_user[superadmin].this_iam_user_name
  ]

  custom_group_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
  ]

  custom_group_policies = [
    {
      name   = "ForceMFA"
      policy = data.aws_iam_policy_document.force_mfa.json
    }
  ]
}

# Create each user
module "iam_user" {
  for_each              = local.superadmin_users
  source                = "terraform-aws-modules/iam/aws//modules/iam-user"
  version               = "~> 2.0"
  name                  = "${each.key}-superadmin"
  force_destroy         = true
  pgp_key               = each.value
  create_iam_access_key = false

  # The following is dependent on whether a PGP key has been set
  create_iam_user_login_profile = length(each.value) > 0 ? true : false
  password_reset_required       = length(each.value) < 0 ? true : false
}

# AWS IAM Policy Document for Force MFA, as taken from:
# https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_examples_aws_my-sec-creds-self-manage.html
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
      "sts:GetSessionToken"
    ]
    resources = ["*"]
    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["false"]
    }
  }
}
