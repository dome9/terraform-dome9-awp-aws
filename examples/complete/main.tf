terraform {
    required_providers {
        dome9 = {
                source = "dome9/dome9"
                version = ">=1.29.7"
        }
        aws = {
            source  = "hashicorp/aws"
            version = ">= 3.0"
        }
    }
}

# The Dome9 provider is used to interact with the resources supported by Dome9.
# The provider needs to be configured with the proper credentials before it can be used.
# Use the dome9_access_id and dome9_secret_key attributes of the provider to provide the Dome9 access key and secret key.
# The base_url attribute is used to specify the base URL of the Dome9 API.
# The Dome9 provider supports several options for providing these credentials. The following example demonstrates the use of static credentials:
#you can read the Dome9 provider documentation to understand the full set of options available for providing credentials.
#https://registry.terraform.io/providers/dome9/dome9/latest/docs#authentication
provider "dome9" {
	dome9_access_id     = "DOME9_ACCESS_ID"
	dome9_secret_key    = "DOME9_SECRET_KEY"
	base_url            = "https://api.dome9.com/v2/"
}

# AWS Provider Configurations
# The AWS provider is used to interact with the resources supported by AWS.
# The provider needs to be configured with the proper credentials before it can be used.
# Use the access_key, secret_key, and token attributes of the provider to provide the credentials.
# also you can use the shared_credentials_file attribute to provide the path to the shared credentials file.
# The AWS provider supports several options for providing these credentials. The following example demonstrates the use of static credentials:
#you can read the AWS provider documentation to understand the full set of options available for providing credentials.
#https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration
provider "aws" {
	region     = "AWS_REGION"
	access_key = "AWS_ACCESS_KEY"
	secret_key = "AWS_SECRET_KEY"
	token      = "AWS_SESSION_TOKEN"
}

locals {
    dome9_be_account_id = "CLOUDGUARD_BACKEND_ACCOUNT_ID" # Dome9 Data Center BackEnd Account ID
    role_external_trust_secret = "CROSS_ACCOUNT_ROLE_EXTERNAL_ID" # External ID for the cross account role trust
}

# Prerequisite: On board the AWS account to CloudGuard using the Dome9 Cloud Account resource.

resource "aws_iam_role" "cross_account_role" {
    name = "CloudGuard-Connect"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Principal = {
                    AWS = "arn:aws:iam::${local.dome9_be_account_id}:root"
                }
                Action = "sts:AssumeRole"
                Condition = {
                    StringEquals = {
                        "sts:ExternalId" = local.role_external_trust_secret
                    }
                }
            }
        ]
    })

     managed_policy_arns = [
        "arn:aws:iam::aws:policy/SecurityAudit",
        "arn:aws:iam::aws:policy/ReadOnlyAccess"
    ]
}


resource "dome9_cloudaccount_aws" "my_aws_account" {
    name  = "My AWS Account"
    vendor = "aws"
    credentials {
        arn = aws_iam_role.cross_account_role.arn
        secret = local.role_external_trust_secret
        type = "RoleBased"
    }
}

## AWP Onboarding using the Dome9 AWP AWS module

module "terraform-dome9-awp-aws" {
    source = "dome9/awp/aws" 

    # The Id of the AWS account,onboarded to CloudGuard (can be either the Dome9 Cloud Account ID or the AWS Account Number)
    awp_cloud_account_id = dome9_cloudaccount_aws.my_aws_account.id 
    
    # The scan mode for the AWP. Valid values are "inAccount" or "saas".
    awp_scan_mode="inAccount"

    # Optional customizations:
    # awp_cross_account_role_name = "My-CrossAccount-Role"
    # awp_cross_account_role_external_id = "AWP_Fake@ExternalID123"

    # Optional account Settings
    # e.g:  
    #   awp_account_settings_aws = {
    #     scan_machine_interval_in_hours = 24
    #     disabled_regions = ["ap-northeast-1", "ap-northeast-2", ...]
    #     max_concurrent_scans_per_region = 20 
    #     custom_tags = {
    #       tag1 = "value1"
    #       tag2 = "value2"
    #       tag3 = "value3"
    #       ...
    #     }
    # }
}
