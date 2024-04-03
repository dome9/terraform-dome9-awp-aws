output "cloud_account_id" {
  description = "Cloud Guard account ID"
  value       = resource.dome9_awp_aws_onboarding.awp_aws_onboarding_resource.cloud_account_id
}

output "agentless_protection_enabled" {
  description = "AWP Status"
  value       = resource.dome9_awp_aws_onboarding.awp_aws_onboarding_resource.agentless_protection_enabled
}

output "should_update" {
  description = "This module is out of date and should be updated to the latest version."
  value       = resource.dome9_awp_aws_onboarding.awp_aws_onboarding_resource.should_update
}

output "awp_cross_account_role_arn" {
  description = "Value of the cross account role arn that AWP assumes to scan the account"
  value       = aws_iam_role.CloudGuardAWPCrossAccountRole.arn
}

output "missing_awp_private_network_regions" {
  description = "List of regions in which AWP has issue to create virtual private network (VPC)"
  value       = resource.dome9_awp_aws_onboarding.awp_aws_onboarding_resource.missing_awp_private_network_regions
}

output "account_issues" {
  description = "Indicates if there are any issues with AWP in the account"
  value       = resource.dome9_awp_aws_onboarding.awp_aws_onboarding_resource.account_issues
}
