# 1. Providers Configuration

# The CloudGuard Dome9 provider is used to interact with the resources supported by Dome9.
# https://registry.terraform.io/providers/dome9/dome9/latest/docs#authentication
provider "dome9" {
  dome9_access_id  = "DOME9_ACCESS_ID"
  dome9_secret_key = "DOME9_SECRET_KEY"
  base_url         = "https://api.dome9.com/v2/"
}

# AWS Provider Configurations
# The AWS provider is used to interact with the resources supported by AWS.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration
provider "aws" {
  # e.g.
  region     = "AWS_REGION"
  access_key = "AWS_ACCESS_KEY"
  secret_key = "AWS_SECRET_KEY"
  token      = "AWS_SESSION_TOKEN"
}

locals {
  dome9_be_account_id        = "CLOUDGUARD_BACKEND_ACCOUNT_ID"  # Dome9 Data Center BackEnd Account ID
  role_external_trust_secret = "CROSS_ACCOUNT_ROLE_EXTERNAL_ID" # External ID for the cross account role trust
}

# 2. Pre-requisite: Onborded AWS Account to CloudGuard Dome9
# [!NOTE] If the AWS account is already onboarded, you can skip this step.

# https://registry.terraform.io/providers/dome9/dome9/latest/docs/resources/cloudaccount_aws
resource "dome9_cloudaccount_aws" "my_aws_account" {
  name   = "My AWS Account"
  vendor = "aws"
  
  # e.g. more details: https://registry.terraform.io/providers/dome9/dome9/latest/docs/resources/cloudaccount_aws#aws_account_id
  credentials {
    arn    = "<AWS_ROLE_ARN>"
    secret = "<AWS_ROLE_SECRET>"
    type   = "RoleBased"         # or UserBase
  }
}

/* ----- Module Usage ----- */

# 3. AWP Onboarding using the Dome9 AWP AWS module

module "terraform-dome9-awp-aws" {
  source               = "dome9/awp-aws/dome9"
  awp_cloud_account_id = dome9_cloudaccount_aws.my_aws_account.id # [<CLOUDGUARD_ACCOUNT_ID | <AWS_ACCOUNT_ID>]  
  awp_scan_mode        = "inAccount"                              # [inAccount | saas]  

  # Optional customizations:
  awp_cross_account_role_name        = "AWPCrossAccountRoleName"
  awp_cross_account_role_external_id = "EXTERNAL_ID"
  awp_additional_tags = {
    "tag1" = "value1"
    "tag2" = "value2"
  }

  # Optional account Settings
  # e.g:  
  awp_account_settings_aws = {
    scan_machine_interval_in_hours  = 24
    disabled_regions                = [] # e.g ["us-east-1", "us-west-2"]
    max_concurrent_scans_per_region = 20
    custom_tags = {
      tag1 = "value1"
      tag2 = "value2"
      tag3 = "value3"
    }
  }
}
