
# CloudGuard AWP (AWS) - Terraform Module

This Terraform module is designed to onboard AWS accounts to Dome9 AWP (Agentless Workload Posture) service.
(https://www.checkpoint.com/dome9/) 

This module use [Check Point CloudGuard Dome9 Provider](https://registry.terraform.io/providers/dome9/dome9/latest/docs)

## Prerequisites

- AWS Account onboarded to Dome9 CloudGuard
- Dome9 CloudGuard API Key and Secret ([Dome9 Provider Authentication](https://registry.terraform.io/providers/dome9/dome9/latest/docs#authentication))
- AWS Credentials ([AWS Provider Authentication](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration)) with permissions to create IAM roles and policies (for more info follow: [AWP Documentation](https://sc1.checkpoint.com/documents/CloudGuard_Dome9/Documentation/Workload-Protection/AWP/AWP-Amazon-SaaS-and-In-Account.htm))


## Usage

```hcl
module "terraform-dome9-awp-aws" {
  source = "dome9/awp-aws/dome9"

  # The Id of the AWS account,onboarded to CloudGuard (can be either the Dome9 Cloud Account ID or the AWS Account Number)
  awp_cloud_account_id = dome9_cloudaccount_aws.my_aws_account.id

  # The scan mode for the AWP. Valid values are: "inAccount", "saas", "inAccountHub", "inAccountSub"
  awp_scan_mode = "inAccount"

  # Optional customizations:
  # e.g:
  awp_cross_account_role_name        = "<CrossAccountRoleName>"
  awp_cross_account_role_external_id = "<ExternalId>"
  awp_centralized_cloud_account_id   = "in case of centralized onboarding, set the 'AWS account id' of the central account where the scans executed"
  awp_additional_tags                = {}  # e.g {"key1" = "value1", "key2" = "value2"}
    

  # Optional account settings
  # e.g:  
  awp_account_settings_aws = {
    scan_machine_interval_in_hours  = 24
    max_concurrent_scans_per_region = 20
    disabled_regions                = []   # e.g ["ap-northeast-1", "ap-northeast-2"]
    custom_tags                     = {}   # e.g {"key1" = "value1", "key2" = "value2"} 
  }
}
```

## Examples
[examples](./examples) directory contains example usage of this module.
 - [basic](./examples/basic) - A basic example of using this module.
 - [complete](./examples/complete) - A complete example of using this module with all the available options.
  
## AWP Terraform template
| Version | 8    |
|---------|------| 

<!-- BEGIN_TF_HEADER_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >=5.30.0 |
| <a name="requirement_dome9"></a> [dome9](#requirement\_dome9) | >=1.29.7 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >=3.4.2 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >=2.5.1 |
<!-- END_TF_HEADER_DOCS -->

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_awp_cloud_account_id"></a> [awp_cloud_account_id](#input\_awp\_cloud\_account\_id) | The Id of the AWS account, onboarded to CloudGuard (can be either the Dome9 Cloud Account ID or the AWS Account Number) | `string` | n/a | yes |
| <a name="input_awp_centralized_cloud_account_id"></a> [awp_centralized_cloud_account_id](TODO) | The Id of the central AWS account where the scans take place  | `string` | n/a | in case of inAccountSub scan mode |
| <a name="input_awp_scan_mode"></a> [awp_scan_mode](#input\_awp\_scan\_mode) | The scan mode for the AWP `[ "inAccount" \| "saas" \| "inAccountHub" \| "inAccountSub" ]`| `string` | "inAccount" | yes |
| <a name="input_awp_cross_account_role_name"></a> [awp_cross_account_role_name](#input\_awp\_cross\_account\_role\_name) | AWP Cross account role name | `string` | `CloudGuardAWPCrossAccountRole` | no |
| <a name="input_awp_cross_account_role_external_id"></a> [awp_cross_account_role_external_id](#input\_awp\_cross\_account\_role\_external\_id) | AWP Cross account role external id | `string` | `null` (auto-generated) | no |
| <a name="input_awp_additional_tags"></a> [awp_additional_tags](#input\_awp\_additional\_tags) | Additional tags to be added to all aws resources created by this module  | `map(string)` | `{}` | no |
|  [awp_account_settings_aws](#input\_awp\_account\_settings\_aws) | AWP Account settings for AWS, supported only for inAccount and saas scan mode | object | `null` | no |

<br/>

**<a name="input_awp_account_settings_aws"></a> [awp_account_settings_aws](#input\_awp\_account\_settings\_aws) variable is an object that contains the following attributes:**
| Name | Description | Type | Default | Valid Values |Required |
|------|-------------|------|---------|:--------:|:--------:|
| <a name="input_scan_machine_interval_in_hours"></a> [scan_machine_interval_in_hours](#input\_scan\_machine\_interval\_in\_hours) | Scan machine interval in hours | `number` | `24` | InAccount: `>=4`, SaaS: `>=24` | no |
| <a name="input_max_concurrent_scans_per_region"></a> [max_concurrent_scans_per_region](#input\_max\_concurrent\_scans\_per\_region) | Maximum concurrent scans per region | `number` | `20` | `1` - `20` | no |
| <a name="input_custom_tags"></a> [custom_tags](#input\_custom\_tags) | Custom tags to be added to AWP dynamic resources | `map(string)` | `{}` | `{"key" = "value", ...}` | no |
| <a name="input_disabled_regions"></a> [disabled_regions](#input\_disabled\_regions) | List of AWS regions to disable AWP scanning | `list(string)` | `[]` | `["us-east-1", ...]`| no |

<!-- BEGIN_TF_DOCS -->
## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.CloudGuardAWPSnapshotsUtilsLogGroup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_policy.CloudGuardAWPCrossAccountRolePolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.CloudGuardAWPKeyReplicationPolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.CloudGuardAWPKeyUsagePolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.CloudGuardAWPProxyLambdaManagementPolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.CloudGuardAWPReEncryptionPolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.CloudGuardAWPReaderPolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.CloudGuardAWPScannersPolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.CloudGuardAWPScannersReaderPolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.CloudGuardAWPSecurityGroupManagementPolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.CloudGuardAWPSnapshotsPolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.CloudGuardAWPSnapshotsUtilsLambdaExecutionRolePolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.CloudGuardAWPVpcManagementPolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy_attachment.CloudGuardAWPCrossAccountRolePolicyAttachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_policy_attachment.CloudGuardAWPKeyReplicationPolicyAttachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_policy_attachment.CloudGuardAWPKeyUsagePolicyAttachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_policy_attachment.CloudGuardAWPProxyLambdaManagementPolicyAttachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_policy_attachment.CloudGuardAWPReEncryptionPolicyAttachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_policy_attachment.CloudGuardAWPReaderPolicyAttachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_policy_attachment.CloudGuardAWPScannersPolicyAttachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_policy_attachment.CloudGuardAWPScannersReaderPolicyAttachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_policy_attachment.CloudGuardAWPSecurityGroupManagementPolicyAttachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_policy_attachment.CloudGuardAWPSnapshotsPolicyAttachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_policy_attachment.CloudGuardAWPSnapshotsUtilsLambdaExecutionRolePolicyAttachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_policy_attachment.CloudGuardAWPVpcManagementPolicyAttachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_role.CloudGuardAWPCrossAccountRole](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.CloudGuardAWPOperatorRole](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.CloudGuardAWPSnapshotsUtilsLambdaExecutionRole](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_kms_alias.CloudGuardAWPKeyAlias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.CloudGuardAWPKey](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_lambda_function.CloudGuardAWPSnapshotsUtilsFunction](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [dome9_awp_aws_onboarding.awp_aws_onboarding_resource](https://registry.terraform.io/providers/dome9/dome9/latest/docs/resources/awp_aws_onboarding) | resource |
| [local_file.CloudGuardAWPSnapshotsUtilsFunctionZip](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_account_issues"></a> [account\_issues](#output\_account\_issues) | Indicates if there are any issues with AWP in the account |
| <a name="output_agentless_protection_enabled"></a> [agentless\_protection\_enabled](#output\_agentless\_protection\_enabled) | AWP Status |
| <a name="output_awp_cross_account_role_arn"></a> [awp\_cross\_account\_role\_arn](#output\_awp\_cross\_account\_role\_arn) | Value of the cross account role arn that AWP assumes to scan the account |
| <a name="output_cloud_account_id"></a> [cloud\_account\_id](#output\_cloud\_account\_id) | Cloud Guard account ID |
| <a name="output_missing_awp_private_network_regions"></a> [missing\_awp\_private\_network\_regions](#output\_missing\_awp\_private\_network\_regions) | List of regions in which AWP has issue to create virtual private network (VPC) |
| <a name="output_should_update"></a> [should\_update](#output\_should\_update) | This module is out of date and should be updated to the latest version. |
<!-- END_TF_DOCS -->

# FAQ & Troubleshooting

> [!IMPORTANT]
> The warning message **"Warning: Response body is not recognized as UTF-8"** is expected and is a known issue with the `http` provider.
> This warning occurs because the data-source `data.http.DownloadCloudGuardAWPSnapshotsUtilsFunctionZip` is retrieving a binary file, which may not be encoded in UTF-8 format.
> As a result, the `http` provider raises this warning. 
> It does not indicate any error or problem with the functionality of the module.