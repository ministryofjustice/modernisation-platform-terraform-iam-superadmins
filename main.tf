# You can define superadmin usernames, and their keybase key if applicable, below, and this will automatically create:
# - their account
# - an attachment to the "superadmins" group, which has the IAM policy of AdministratorAccess
# - if a keybase key is provided, it will also create their user login profile
locals {
  superadmin_users = {
    "david.elliott" = "keybase:davidkelliott"
    "jake.mulley"   = ""
    "phil.horrocks" = ""
  }
}

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

module "iam_group_admins_with_policies" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-policies"
  version = "~> 2.0"
  name    = "superadmins"

  group_users = [
    for superadmin in keys(local.superadmin_users) : module.iam_user[superadmin].this_iam_user_name
  ]

  custom_group_policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess",
  ]
}

module "iam_user" {
  for_each                      = local.superadmin_users
  source                        = "terraform-aws-modules/iam/aws//modules/iam-user"
  version                       = "~> 2.0"
  name                          = "${each.key}-superadmin"
  force_destroy                 = true
  pgp_key                       = each.value
  create_iam_user_login_profile = length(each.value) > 0 ? true : false
  create_iam_access_key         = false
}
