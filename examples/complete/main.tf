terraform {
    required_providers {
        dome9 = {
                source = "dome9/dome9"
                version = ">=1.29.6"
        }
        aws = {
            source  = "hashicorp/aws"
            version = ">= 3.0"
        }
    }
}

provider "dome9" {
    dome9_access_id  = "************"
    dome9_secret_key = "************"
    base_url         = "https://api.dome9.com/v2/"
}

provider "aws" {
        region = "us-west-2"
        profile = "default"
}

locals {
    dome9_be_account_id = "0123456789" # Dome9 Data Center BackEnd Account ID
    role_external_trust_secret = "******************"
}

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
    #     max_concurrence_scans_per_region = 20 
    #     custom_tags = {
    #       tag1 = "value1"
    #       tag2 = "value2"
    #       tag3 = "value3"
    #       ...
    #     }
    # }
}
