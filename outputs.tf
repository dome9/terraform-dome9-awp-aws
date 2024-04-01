# output "awp_scan_mode" {
#     description = "AWP scan mode <inAccount|saas>"
#     value       = local.scan_mode
# }

# output "awp_cloudguard_account_id" {
#     description = "AWS Cloud Account ID"
#     value       = data.dome9_cloudaccount_aws.cloud_account.id
# }

# output "awp_cross_account_role_name" {
#     value = aws_iam_role.CloudGuardAWPCrossAccountRole.name
# }

# output "cross_account_role_external_id" {
#     value = local.cross_account_role_external_id
  
# }