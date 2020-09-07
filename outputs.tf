output "superadmin_passwords" {
  sensitive = true
  value = {
    for user in module.iam_user :
    user.this_iam_user_name => user.this_iam_user_login_profile_encrypted_password
    if length(user.pgp_key) > 0
  }
}
