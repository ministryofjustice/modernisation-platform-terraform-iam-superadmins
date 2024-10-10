output "superadmin_passwords" {
  value = {
    for user in module.iam_user :
    user.iam_user_name => user.iam_user_login_profile_encrypted_password
    if length(user.pgp_key) > 0
  }
  description = "Map of users and PGP-encrypted passwords, e.g. { bob: 'abcdefg123456' }"
}

output "iam_user_names" {
  value       = [for user in module.iam_user : user.iam_user_name]
  description = "List of usernames for simple validation"
}
