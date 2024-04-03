output "cloud_account_id" {
  description = "Cloud Guard account ID"
  value       = module.terraform-dome9-awp-aws[0].cloud_account_id
}

output "agentless_protection_enabled" {
  description = "AWP Status"
  value       = module.terraform-dome9-awp-aws[0].agentless_protection_enabled
}

output "should_update" {
  description = "Should update"
  value       = module.terraform-dome9-awp-aws[0].should_update
}

output "awp_cross_account_role_arn" {
  description = "Value of the cross account role arn"
  value       = module.terraform-dome9-awp-aws[0].awp_cross_account_role_arn
}

output "missing_awp_private_network_regions" {
  description = "List of regions in which AWP has issue to create virtual private network (VPC)"
  value       = module.terraform-dome9-awp-aws[0].missing_awp_private_network_regions
}

output "account_issues" {
  description = "Indicates if there are any issues with AWP in the account"
  value       = module.terraform-dome9-awp-aws[0].account_issues
}