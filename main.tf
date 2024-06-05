# This Terraform file defines the configuration for creating an IAM roles that allows CloudGuard access to the AWS account.

# The `data "aws_partition" "current"` block retrieves information about the current AWS partition.
data "aws_partition" "current" {}

# The `data "aws_caller_identity" "current"` block retrieves information about the current AWS caller identity.
data "aws_caller_identity" "current" {}

# The `data "aws_region" "current"` block retrieves information about the current AWS region.
data "aws_region" "current" {
  lifecycle {
    postcondition {
      condition     = self.name == local.region
      error_message = "Error: AWP must be deployed in the same region as the CloudGuard Data Center: ${local.region} (Not in ${self.name})"
    }
  }
}

data "aws_organizations_organization" "org" {}

data "dome9_cloudaccount_aws" "cloud_account" {
  id = var.awp_cloud_account_id
}

data "dome9_cloudaccount_aws" "centralized_cloud_account" {
  count = var.awp_centralized_cloud_account_id != null ? 1 : 0
  id = var.awp_centralized_cloud_account_id
}

# The data source retrieves the onboarding data of an AWS account in Dome9 AWP.
data "dome9_awp_aws_onboarding_data" "dome9_awp_aws_onboarding_data_source" {
  cloud_account_id = data.dome9_cloudaccount_aws.cloud_account.id
}

# Define local values used in multiple places in the configuration.
locals {
  awp_module_version                                = "8"
  scan_mode                                         = var.awp_scan_mode
  stage                                             = data.dome9_awp_aws_onboarding_data.dome9_awp_aws_onboarding_data_source.stage
  region                                            = data.dome9_awp_aws_onboarding_data.dome9_awp_aws_onboarding_data_source.region
  cloud_guard_backend_account_id                    = data.dome9_awp_aws_onboarding_data.dome9_awp_aws_onboarding_data_source.cloud_guard_backend_account_id
  agentless_bucket_name                             = data.dome9_awp_aws_onboarding_data.dome9_awp_aws_onboarding_data_source.agentless_bucket_name
  remote_functions_prefix_key                       = data.dome9_awp_aws_onboarding_data.dome9_awp_aws_onboarding_data_source.remote_functions_prefix_key
  remote_snapshots_utils_function_name              = data.dome9_awp_aws_onboarding_data.dome9_awp_aws_onboarding_data_source.remote_snapshots_utils_function_name
  remote_snapshots_utils_function_run_time          = data.dome9_awp_aws_onboarding_data.dome9_awp_aws_onboarding_data_source.remote_snapshots_utils_function_run_time
  remote_snapshots_utils_function_time_out          = data.dome9_awp_aws_onboarding_data.dome9_awp_aws_onboarding_data_source.remote_snapshots_utils_function_time_out
  awp_client_side_security_group_name               = data.dome9_awp_aws_onboarding_data.dome9_awp_aws_onboarding_data_source.awp_client_side_security_group_name
  cross_account_role_external_id                    = var.awp_cross_account_role_external_id != null ? var.awp_cross_account_role_external_id : data.dome9_awp_aws_onboarding_data.dome9_awp_aws_onboarding_data_source.cross_account_role_external_id
  remote_snapshots_utils_function_s3_pre_signed_url = data.dome9_awp_aws_onboarding_data.dome9_awp_aws_onboarding_data_source.remote_snapshots_utils_function_s3_pre_signed_url
  centralized_external_account_id                   = var.awp_centralized_cloud_account_id != null ? data.dome9_cloudaccount_aws.centralized_cloud_account[0].external_account_number : ""
  aws_organization_id                               = data.aws_organizations_organization.org.id

  is_saas_scan_mode                     = local.scan_mode == "saas"
  is_in_account_scan_mode               = local.scan_mode == "inAccount"
  is_in_account_hub_scan_mode_condition = local.scan_mode == "inAccountHub"
  is_in_account_sub_scan_mode_condition = local.scan_mode == "inAccountSub"
  is_scanner_mode_condition             = local.is_in_account_scan_mode || local.is_in_account_hub_scan_mode_condition
  is_scanned_mode_condition             = !local.is_in_account_hub_scan_mode_condition
  is_proxy_lambda_required_condition    = !local.is_in_account_sub_scan_mode_condition
  is_hosting_key_condition              = local.is_in_account_hub_scan_mode_condition || local.is_saas_scan_mode
  is_reencrypt_required_condition       = local.is_saas_scan_mode || local.is_in_account_sub_scan_mode_condition

  common_tags = merge({
    Owner                     = "CG.AWP"
    Terraform                 = "true"
    "CG.AL.TF.MODULE_VERSION" = local.awp_module_version
  }, var.awp_additional_tags != null ? var.awp_additional_tags : {})

}

# This policy provides the cross-account-role with the ability to read AWP scanner resources
resource "aws_iam_policy" "CloudGuardAWPScannersReaderPolicy" {
  count = local.is_scanner_mode_condition ? 1 : 0
  name  = "CloudGuardAWPScannersReaderPolicy"
  tags  = local.common_tags # TODO need this?, not appears in YAML?

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:DescribeRegions"
        ]
        Resource = "*"
      }
    ]
  })
}

# Policy attachment for 'CloudGuardAWPScannersReaderPolicy'
resource "aws_iam_policy_attachment" "CloudGuardAWPScannersReaderPolicyAttachment" {
  count      = local.is_scanner_mode_condition ? 1 : 0
  name       = "CloudGuardAWPScannersReaderPolicyAttachment"
  policy_arn = aws_iam_policy.CloudGuardAWPScannersReaderPolicy[count.index].arn
  roles      = [aws_iam_role.CloudGuardAWPCrossAccountRole.name]
}

# This policy provides the cross-account-role the permissions to read client machines resources
resource "aws_iam_policy" "CloudGuardAWPReaderPolicy" {
  count = local.is_scanned_mode_condition ? 1 : 0
  name  = "CloudGuardAWPReaderPolicy"
  tags  = local.common_tags

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeRegions",
          "ec2:DescribeVolumes"
        ]
        Resource = "*"
      }
    ]
  })
}

# Policy attachment for 'CloudGuardAWPReaderPolicy'
resource "aws_iam_policy_attachment" "CloudGuardAWPReaderPolicyAttachment" {
  count      = local.is_scanned_mode_condition ? 1 : 0
  name       = "CloudGuardAWPReaderPolicyAttachment"
  policy_arn = aws_iam_policy.CloudGuardAWPReaderPolicy[count.index].arn
  roles      = [aws_iam_role.CloudGuardAWPCrossAccountRole.name]
}

# This policy provides the proxy lambda the permissions to create and teardown VPC setup
resource "aws_iam_policy" "CloudGuardAWPVpcManagementPolicy" {
  count = local.is_scanner_mode_condition ? 1 : 0
  name  = "CloudGuardAWPVpcManagementPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSubnet",
          "ec2:CreateVpcEndpoint",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Owner" = "CG.AWP"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc",
          "ec2:CreateSubnet",
          "ec2:CreateSecurityGroup",
          "ec2:CreateVpcEndpoint",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Owner" = "CG.AWP"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeRouteTables",
          "ec2:DescribeNetworkAcls",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeSecurityGroupRules",
          "ec2:DescribeVpcEndpoints"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:ModifySubnetAttribute",
          "ec2:AssociateRouteTable",
          "ec2:DeleteVpc",
          "ec2:DeleteSubnet",
          "ec2:DeleteVolume",
          "ec2:DeleteInternetGateway",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:DeleteSecurityGroup",
          "ec2:DeleteVpcEndpoints",
          "ec2:CreateNetworkAclEntry"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Owner" = "CG.AWP"
          }
        }
      }
    ]
  })
}

# Policy attachment for 'CloudGuardAWPReaderPolicy'
resource "aws_iam_policy_attachment" "CloudGuardAWPVpcManagementPolicyAttachment" {
  count      = local.is_scanner_mode_condition ? 1 : 0
  name       = "CloudGuardAWPVpcManagementPolicyAttachment"
  policy_arn = aws_iam_policy.CloudGuardAWPVpcManagementPolicy[count.index].arn
  roles      = [aws_iam_role.CloudGuardAWPSnapshotsUtilsLambdaExecutionRole.name]
}

# This policy provides the cross-account-role permissions to manage the proxy lambda
resource "aws_iam_policy" "CloudGuardAWPProxyLambdaManagementPolicy" {
  count = local.is_proxy_lambda_required_condition ? 1 : 0
  name  = "CloudGuardAWPProxyLambdaManagementPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:GetFunction",
          "lambda:GetLayerVersion",
          "lambda:TagResource",
          "lambda:ListTags",
          "lambda:UntagResource",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:GetFunctionConfiguration"
        ]
        Resource = aws_lambda_function.CloudGuardAWPSnapshotsUtilsFunction[count.index].arn
      },
      {
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "arn:${data.aws_partition.current.partition}:s3:::${local.agentless_bucket_name}/${local.remote_functions_prefix_key}*"
      }
    ]
  })
}

# Policy attachment for 'CloudGuardAWPProxyLambdaManagementPolicy'
resource "aws_iam_policy_attachment" "CloudGuardAWPProxyLambdaManagementPolicyAttachment" {
  count      = local.is_proxy_lambda_required_condition ? 1 : 0
  name       = "CloudGuardAWPProxyLambdaManagementPolicyAttachment"
  policy_arn = aws_iam_policy.CloudGuardAWPProxyLambdaManagementPolicy[count.index].arn
  roles      = [aws_iam_role.CloudGuardAWPCrossAccountRole.name]
}

# This policy provides the cross-account-role permissions manage securit-group in case using client's default VPC
resource "aws_iam_policy" "CloudGuardAWPSecurityGroupManagementPolicy" {
  count = local.is_scanner_mode_condition ? 1 : 0
  name  = "CloudGuardAWPSecurityGroupManagementPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSecurityGroup"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Owner" = "CG.AWP"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeManagedPrefixLists",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSecurityGroupRules",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:CreateTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteSecurityGroup"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Owner" = "CG.AWP"
          }
        }
      }
    ]
  })
}

# Policy attachment for 'CloudGuardAWPSecurityGroupManagementPolicy'
resource "aws_iam_policy_attachment" "CloudGuardAWPSecurityGroupManagementPolicyAttachment" {
  count      = local.is_scanner_mode_condition ? 1 : 0
  name       = "CloudGuardAWPSecurityGroupManagementPolicyAttachment"
  policy_arn = aws_iam_policy.CloudGuardAWPSecurityGroupManagementPolicy[count.index].arn
  roles      = [aws_iam_role.CloudGuardAWPCrossAccountRole.name]
}

# This policy provides the AWP role the permissions to handle snapshots creation for the scanned machines
resource "aws_iam_policy" "CloudGuardAWPSnapshotsPolicy" {
  count = local.is_scanned_mode_condition ? 1 : 0
  name  = "CloudGuardAWPSnapshotsPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:ec2:*:${data.aws_caller_identity.current.account_id}:volume/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CopySnapshot",
          "ec2:CreateSnapshot"
        ]
        Resource : "arn:${data.aws_partition.current.partition}:ec2:*::snapshot/*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Owner" = "CG.AWP"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource : "arn:${data.aws_partition.current.partition}:ec2:*::snapshot/*"
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = ["CreateSnapshot", "CopySnapshot"]
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeRegions",
          "ec2:DescribeSnapshots"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteSnapshot",
          "ec2:ModifySnapshotAttribute"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Owner" = "CG.AWP"
          }
        }
      }
    ]
  })
}

# Policy attachment for 'CloudGuardAWPSnapshotsPolicy' not inAccountSub case
resource "aws_iam_policy_attachment" "CloudGuardAWPSnapshotsPolicyAttachment" {
  count      = local.is_scanned_mode_condition ? 1 : 0
  name       = "CloudGuardAWPSnapshotsPolicyAttachment"
  policy_arn = aws_iam_policy.CloudGuardAWPSnapshotsPolicy[count.index].arn
  roles      = local.is_in_account_sub_scan_mode_condition ? [aws_iam_role.CloudGuardAWPOperatorRole[0].name] : [aws_iam_role.CloudGuardAWPSnapshotsUtilsLambdaExecutionRole.name]
}

# This policy provides the AWP proxy lambda with the permissions to manage AWP scanners
resource "aws_iam_policy" "CloudGuardAWPScannersPolicy" {
  count = local.is_scanner_mode_condition ? 1 : 0
  name  = "CloudGuardAWPScannersPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:DescribeRegions",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:TerminateInstances",
          "ec2:DeleteVolume"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Owner" = "CG.AWP"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole"
        ]
        Resource : "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot"
      }
    ]
  })
}

# Policy attachment for 'CloudGuardAWPScannersPolicy'
resource "aws_iam_policy_attachment" "CloudGuardAWPScannersPolicyAttachment" {
  count      = local.is_scanner_mode_condition ? 1 : 0
  name       = "CloudGuardAWPScannersPolicyAttachment"
  policy_arn = aws_iam_policy.CloudGuardAWPScannersPolicy[count.index].arn
  roles      = [aws_iam_role.CloudGuardAWPSnapshotsUtilsLambdaExecutionRole.name]
}

# This policy provides the AWP proxy lambda with the permissions to use the AWP key in case scanner attached with a re-encrypted snapshot
resource "aws_iam_policy" "CloudGuardAWPKeyUsagePolicy" {
  count = local.is_scanner_mode_condition ? 1 : 0
  name  = "CloudGuardAWPKeyUsagePolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = local.is_in_account_hub_scan_mode_condition ? aws_kms_key.CloudGuardAWPKey[count.index].arn : "*"
      }
    ]
  })
}

# Policy attachment for 'CloudGuardAWPKeyUsagePolicy'
resource "aws_iam_policy_attachment" "CloudGuardAWPKeyUsagePolicyAttachment" {
  count      = local.is_scanner_mode_condition ? 1 : 0
  name       = "CloudGuardAWPKeyUsagePolicyAttachment"
  policy_arn = aws_iam_policy.CloudGuardAWPKeyUsagePolicy[count.index].arn
  roles      = [aws_iam_role.CloudGuardAWPSnapshotsUtilsLambdaExecutionRole.name]
}

# This policy provides the cross-account-role with the permissions to replicate the AWP key to another region
resource "aws_iam_policy" "CloudGuardAWPKeyReplicationPolicy" {
  count = local.is_hosting_key_condition ? 1 : 0
  name  = "CloudGuardAWPKeyReplicationPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:DescribeKey",
          "kms:ReplicateKey",
          "kms:PutKeyPolicy",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion",
          "kms:TagResource",
          "kms:CreateAlias",
          "kms:DeleteAlias",
          "kms:GetKeyPolicy"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:kms:*:${data.aws_caller_identity.current.account_id}:key/${aws_kms_key.CloudGuardAWPKey[0].id}"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:CreateAlias",
          "kms:DeleteAlias"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:kms:*:${data.aws_caller_identity.current.account_id}:alias/CloudGuardAWPKey"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:CreateKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# Policy attachment for 'CloudGuardAWPKeyReplicationPolicy'
resource "aws_iam_policy_attachment" "CloudGuardAWPKeyReplicationPolicyAttachment" {
  count      = local.is_hosting_key_condition ? 1 : 0
  name       = "CloudGuardAWPKeyReplicationPolicyAttachment"
  policy_arn = aws_iam_policy.CloudGuardAWPKeyReplicationPolicy[count.index].arn
  roles = [
    aws_iam_role.CloudGuardAWPCrossAccountRole.name,
    aws_iam_role.CloudGuardAWPSnapshotsUtilsLambdaExecutionRole.name
  ]
}

# This policy provides the AWP role the permissions to handle re-encrypt encrypted snapshots to the AWP key
resource "aws_iam_policy" "CloudGuardAWPReEncryptionPolicy" {
  count = local.is_reencrypt_required_condition ? 1 : 0
  name  = "CloudGuardAWPReEncryptionPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:ReEncryptTo",
          "kms:RevokeGrant",
          "kms:DescribeKey"
        ]
        Resource = local.is_saas_scan_mode ? aws_kms_key.CloudGuardAWPKey[count.index].arn : "arn:${data.aws_partition.current.partition}:kms:*:${local.centralized_external_account_id}:alias/CloudGuardAWPKey"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:ReEncryptFrom",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Policy attachment for 'CloudGuardAWPReEncryptionPolicy'
resource "aws_iam_policy_attachment" "CloudGuardAWPReEncryptionPolicyAttachment" {
  count      = local.is_reencrypt_required_condition ? 1 : 0
  name       = "CloudGuardAWPReEncryptionPolicyAttachment"
  policy_arn = aws_iam_policy.CloudGuardAWPReEncryptionPolicy[count.index].arn
  roles      = local.is_saas_scan_mode ? [aws_iam_role.CloudGuardAWPSnapshotsUtilsLambdaExecutionRole.name] : [aws_iam_role.CloudGuardAWPOperatorRole[0].name]
}

# The `resource "aws_iam_role" "CloudGuardAWPCrossAccountRole"` block defines an IAM role that is used to allow CloudGuard AWP to access the AWS account.
resource "aws_iam_role" "CloudGuardAWPCrossAccountRole" {
  name        = var.awp_cross_account_role_name
  description = "Role"

  # The `assume_role_policy` attribute specifies the IAM policy that determines who can assume the role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = local.cloud_guard_backend_account_id # The AWS account id of the CloudGuard backend account.
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = local.cross_account_role_external_id # The external id of the cross account role.
        }
      }
    }]
  })

  tags = local.common_tags

  # The `depends_on` attribute specifies that this IAM role depends on the `aws_lambda_function.CloudGuardAWPSnapshotsUtilsFunction` resource.
  depends_on = [aws_lambda_function.CloudGuardAWPSnapshotsUtilsFunction]
}

# The CloudGuardAWPCrossAccountRolePolicy resource defines an IAM policy that is used to define the permissions for the CloudGuardAWPCrossAccountRole.
resource "aws_iam_policy" "CloudGuardAWPCrossAccountRolePolicy" {
  count       = 1
  name        = "CloudGuardAWPCrossAccountRolePolicy"
  description = "Policy for CloudGuardAWPCrossAccountRole"
  tags        = local.common_tags

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudformation:DescribeStacks"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:cloudformation:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stack/*"
      },
      {
        Effect   = "Allow"
        Action   = local.is_in_account_sub_scan_mode_condition ? ["iam:GetRole"] : ["cloudformation:DescribeStacks"]
        Resource = local.is_in_account_sub_scan_mode_condition ? aws_iam_role.CloudGuardAWPOperatorRole[0].arn : "arn:${data.aws_partition.current.partition}:cloudformation:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stack/*"
      },
      {
        Effect   = "Allow",
        Action   = "iam:ListRoleTags",
        Resource = aws_iam_role.CloudGuardAWPCrossAccountRole.arn
      }
    ]
  })
}

# Policy attachment for 'CloudGuardAWPCrossAccountRolePolicy'
resource "aws_iam_policy_attachment" "CloudGuardAWPCrossAccountRolePolicyAttachment" {
  count      = 1
  name       = "CloudGuardAWPCrossAccountRolePolicyAttachment"
  policy_arn = aws_iam_policy.CloudGuardAWPCrossAccountRolePolicy[0].arn
  roles      = [aws_iam_role.CloudGuardAWPCrossAccountRole.name]
}

# The CloudGuardAWPSnapshotsUtilsLambdaExecutionRole resource defines an IAM role that is used to allow the CloudGuardAWPSnapshotsUtilsFunction to execute.
resource "aws_iam_role" "CloudGuardAWPSnapshotsUtilsLambdaExecutionRole" {
  name        = "CloudGuardAWPSnapshotsUtilsLambdaExecutionRole"
  description = "CloudGuard AWP proxy lambda function execution role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = local.common_tags
}

# Policy for CloudGuardAWPSnapshotsUtilsLambdaExecutionRole
resource "aws_iam_policy" "CloudGuardAWPSnapshotsUtilsLambdaExecutionRolePolicy" {
  count       = local.is_proxy_lambda_required_condition ? 1 : 0
  name        = "CloudGuardAWPSnapshotsUtilsLambdaExecutionRolePolicy"
  description = "Policy for managing snapshots at client side and delete AWP KMS keys"
  tags        = local.common_tags

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["${aws_cloudwatch_log_group.CloudGuardAWPSnapshotsUtilsLogGroup[count.index].arn}:*"]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = local.is_in_account_hub_scan_mode_condition ? ["sts:AssumeRole"] : ["ec2:CreateTags"]
        Resource = local.is_in_account_hub_scan_mode_condition ? "arn:${data.aws_partition.current.partition}:iam::*:role/CloudGuardAWPOperatorRole" : "*"
      }
    ]
  })
}

# Policy attachment for 'CloudGuardAWPSnapshotsUtilsLambdaExecutionRolePolicy'
resource "aws_iam_policy_attachment" "CloudGuardAWPSnapshotsUtilsLambdaExecutionRolePolicyAttachment" {
  count      = local.is_proxy_lambda_required_condition ? 1 : 0
  name       = "CloudGuardAWPSnapshotsUtilsLambdaExecutionRolePolicyAttachment"
  policy_arn = aws_iam_policy.CloudGuardAWPSnapshotsUtilsLambdaExecutionRolePolicy[count.index].arn
  roles      = [aws_iam_role.CloudGuardAWPSnapshotsUtilsLambdaExecutionRole.name]
}

# The CloudGuardAWPOperatorRole
resource "aws_iam_role" "CloudGuardAWPOperatorRole" {
  count       = local.is_in_account_sub_scan_mode_condition ? 1 : 0
  name        = "CloudGuardAWPOperatorRole"
  description = "Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = local.centralized_external_account_id
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = local.common_tags
}

# CloudGuardAWPSnapshotsUtilsLogGroup : The CloudWatch log group that is used to store the logs of the CloudGuardAWPSnapshotsUtilsFunction.
resource "aws_cloudwatch_log_group" "CloudGuardAWPSnapshotsUtilsLogGroup" {
  count             = local.is_proxy_lambda_required_condition ? 1 : 0
  name              = "/aws/lambda/${aws_lambda_function.CloudGuardAWPSnapshotsUtilsFunction[count.index].function_name}"
  retention_in_days = 30
  depends_on = [
    aws_lambda_function.CloudGuardAWPSnapshotsUtilsFunction
  ]
  tags = local.common_tags
}

# The DownloadCloudGuardAWPSnapshotsUtilsFunctionZip resource use http data source to download the remote function file from S3 pre-signed URL.
data "http" "DownloadCloudGuardAWPSnapshotsUtilsFunctionZip" {
  url    = local.remote_snapshots_utils_function_s3_pre_signed_url
  method = "GET"
  request_headers = {
    Accept        = "application/zip"
    Accept-Ranges = "bytes"
  }
}

# The CloudGuardAWPSnapshotsUtilsFunctionZip resource defines a local file that is used to store the remote function file to be used in the lambda function.
resource "local_file" "CloudGuardAWPSnapshotsUtilsFunctionZip" {
  filename       = "${local.remote_snapshots_utils_function_name}.zip"
  content_base64 = data.http.DownloadCloudGuardAWPSnapshotsUtilsFunctionZip.response_body_base64
}

# The CloudGuardAWPSnapshotsUtilsFunction resource defines a lambda function that is used to manage remote actions and resources.
resource "aws_lambda_function" "CloudGuardAWPSnapshotsUtilsFunction" {
  count         = local.is_proxy_lambda_required_condition ? 1 : 0
  function_name = local.remote_snapshots_utils_function_name ## TBD allow adding a prefix
  handler       = "snapshots_utils.lambda_handler"
  description   = "CloudGuard AWP Proxy for managing remote actions and resources"
  role          = aws_iam_role.CloudGuardAWPSnapshotsUtilsLambdaExecutionRole.arn
  runtime       = "python3.9"
  memory_size   = 256
  timeout       = local.remote_snapshots_utils_function_time_out # TODO defined wrongly in YAML
  filename      = local_file.CloudGuardAWPSnapshotsUtilsFunctionZip.filename

  environment {
    variables = {
      CP_AWP_AWS_ACCOUNT         = local.cloud_guard_backend_account_id
      CP_AWP_CURRENT_ACCOUNT     = data.aws_caller_identity.current.account_id
      CP_AWP_SCANNER_ACCOUNT     = local.is_saas_scan_mode ? local.cloud_guard_backend_account_id : data.aws_caller_identity.current.account_id
      CP_AWP_MR_KMS_KEY_ID       = local.is_hosting_key_condition ? aws_kms_key.CloudGuardAWPKey[0].arn : ""
      CP_AWP_MR_KMS_KEY_ALIAS    = local.is_hosting_key_condition ? "alias/CloudGuardAWPKey" : ""
      CP_AWP_SCAN_MODE           = local.scan_mode
      CP_AWP_SECURITY_GROUP_NAME = local.awp_client_side_security_group_name
      AWS_PARTITION              = data.aws_partition.current.partition
    }
  }

  tags = merge({
    Terraform                 = "true"
    "CG.AL.TF.MODULE_VERSION" = local.awp_module_version
  }, local.common_tags)
}

resource "aws_kms_key" "CloudGuardAWPKey" {
  count                   = local.is_hosting_key_condition ? 1 : 0
  description             = "CloudGuard AWP Multi-Region primary key for snapshots re-encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  # Conditionally set multi-region based on IsChinaPartition
  multi_region = data.aws_partition.current.partition == "aws-cn" ? false : true

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "cloud-guard-awp-key"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow AWP BE Management"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${local.cloud_guard_backend_account_id}:root"
        }
        Action = [
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion",
          "kms:PutKeyPolicy",
          "kms:DescribeKey",
          "kms:GetKeyPolicy"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow usage of the key by scanner launched from AWP BE or Proxy lambda"
        Effect = "Allow"
        Principal = {
          AWS = local.is_saas_scan_mode ? "arn:${data.aws_partition.current.partition}:iam::${local.cloud_guard_backend_account_id}:root" : aws_iam_role.CloudGuardAWPSnapshotsUtilsLambdaExecutionRole.arn
        }
        Action = [
          "kms:ReEncryptFrom",
          "kms:GenerateDataKey*",
        ]
        Resource = "*"
      },
      {
        Sid    = local.is_saas_scan_mode ? "Allow re-encryption to this key by AWP BE" : "Allow re encryption to this key by all Sub accounts in the organization"
        Effect = "Allow"
        Principal = {
          AWS = local.is_saas_scan_mode ? "arn:${data.aws_partition.current.partition}:iam::${local.cloud_guard_backend_account_id}:root" : "*"
        }
        Action = [
          "kms:DescribeKey",
          "kms:ReEncryptTo",
          "kms:GenerateDataKey*"
        ]
        Resource  = "*"
        Condition = local.is_saas_scan_mode ? {} : { StringEquals = { "aws:PrincipalOrgId" = local.aws_organization_id } }
      },
      {
        Sid    = local.is_saas_scan_mode ? "Allow attachment of persistent resources" : "Allow attachment of persistent resources for all sub accounts in the organization"
        Effect = "Allow"
        Principal = {
          AWS = local.is_saas_scan_mode ? "arn:${data.aws_partition.current.partition}:iam::${local.cloud_guard_backend_account_id}:root" : "*"
        }
        Action = [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ]
        Resource  = "*"
        Condition = local.is_saas_scan_mode ? { Bool = { "kms:GrantIsForAWSResource" = true } } : { StringEquals = { "aws:PrincipalOrgId" = local.aws_organization_id } }
      }
    ]
  })
  tags = local.common_tags
}

# The CloudGuardAWPKeyAlias resource defines a KMS key alias that is used to reference the KMS key
resource "aws_kms_alias" "CloudGuardAWPKeyAlias" {
  count         = local.is_hosting_key_condition ? 1 : 0
  name          = "alias/CloudGuardAWPKey"
  target_key_id = aws_kms_key.CloudGuardAWPKey[count.index].arn
  depends_on = [
    aws_kms_key.CloudGuardAWPKey
  ]
}

# aws_lambda_invocation : The Lambda invocation that is used to cleanup dynamic resources before teardown.
resource "aws_lambda_invocation" "CloudGuardAWPSnapshotsUtilsCleanupFunctionInvocation_saas" {
  count         = local.is_saas_scan_mode ? 1 : 0
  function_name = aws_lambda_function.CloudGuardAWPSnapshotsUtilsFunction[count.index].function_name
  input = jsonencode({
    "target_account_id" : data.aws_caller_identity.current.account_id
  })
  lifecycle_scope = "CRUD"

  depends_on = [
    aws_iam_policy_attachment.CloudGuardAWPSnapshotsUtilsLambdaExecutionRolePolicyAttachment,
    aws_cloudwatch_log_group.CloudGuardAWPSnapshotsUtilsLogGroup,
    aws_iam_policy_attachment.CloudGuardAWPKeyReplicationPolicyAttachment,
    aws_iam_policy_attachment.CloudGuardAWPReEncryptionPolicyAttachment,
    aws_iam_policy_attachment.CloudGuardAWPSnapshotsPolicyAttachment,
    aws_iam_policy_attachment.CloudGuardAWPReaderPolicyAttachment
  ]
}

resource "aws_lambda_invocation" "CloudGuardAWPSnapshotsUtilsCleanupFunctionInvocation_inAccount" {
  count         = local.is_in_account_scan_mode ? 1 : 0
  function_name = aws_lambda_function.CloudGuardAWPSnapshotsUtilsFunction[count.index].function_name
  input = jsonencode({
    "target_account_id" : data.aws_caller_identity.current.account_id
  })
  lifecycle_scope = "CRUD"

  depends_on = [
    aws_iam_policy_attachment.CloudGuardAWPSnapshotsUtilsLambdaExecutionRolePolicyAttachment,
    aws_cloudwatch_log_group.CloudGuardAWPSnapshotsUtilsLogGroup,
    aws_iam_policy_attachment.CloudGuardAWPScannersReaderPolicyAttachment,
    aws_iam_policy_attachment.CloudGuardAWPKeyUsagePolicyAttachment,
    aws_iam_policy_attachment.CloudGuardAWPScannersPolicyAttachment,
    aws_iam_policy_attachment.CloudGuardAWPSecurityGroupManagementPolicyAttachment,
    aws_iam_policy_attachment.CloudGuardAWPVpcManagementPolicyAttachment,
    aws_iam_policy_attachment.CloudGuardAWPSnapshotsPolicyAttachment,
    aws_iam_policy_attachment.CloudGuardAWPReaderPolicyAttachment
  ]
}

resource "aws_lambda_invocation" "CloudGuardAWPSnapshotsUtilsCleanupFunctionInvocation_inAccountHub" {
  count         = local.is_in_account_hub_scan_mode_condition ? 1 : 0
  function_name = aws_lambda_function.CloudGuardAWPSnapshotsUtilsFunction[count.index].function_name
  input = jsonencode({
    "target_account_id" : data.aws_caller_identity.current.account_id
  })
  lifecycle_scope = "CRUD"

  depends_on = [
    aws_iam_policy_attachment.CloudGuardAWPSnapshotsUtilsLambdaExecutionRolePolicyAttachment,
    aws_cloudwatch_log_group.CloudGuardAWPSnapshotsUtilsLogGroup,
    aws_iam_policy_attachment.CloudGuardAWPScannersReaderPolicyAttachment,
    aws_iam_policy_attachment.CloudGuardAWPKeyUsagePolicyAttachment,
    aws_iam_policy_attachment.CloudGuardAWPScannersPolicyAttachment,
    aws_iam_policy_attachment.CloudGuardAWPSecurityGroupManagementPolicyAttachment,
    aws_iam_policy_attachment.CloudGuardAWPVpcManagementPolicyAttachment,
    aws_iam_policy_attachment.CloudGuardAWPKeyReplicationPolicyAttachment,
    aws_iam_policy_attachment.CloudGuardAWPReEncryptionPolicyAttachment,
    aws_iam_policy_attachment.CloudGuardAWPSnapshotsPolicyAttachment,
    aws_iam_policy_attachment.CloudGuardAWPReaderPolicyAttachment
  ]
}

resource "time_sleep" "wait_for_cleanup" {
  count           = local.is_in_account_sub_scan_mode_condition ? 1 : 0
  create_duration = "30s"
  depends_on = [ # Wait for the cleanup function invocation to complete before proceeding with the next steps. this list should be identical to dome9 resource dependencies
    aws_iam_policy_attachment.CloudGuardAWPSnapshotsUtilsLambdaExecutionRolePolicyAttachment,
    aws_iam_policy_attachment.CloudGuardAWPCrossAccountRolePolicyAttachment,
    aws_iam_role.CloudGuardAWPCrossAccountRole,
    aws_lambda_invocation.CloudGuardAWPSnapshotsUtilsCleanupFunctionInvocation_saas,
    aws_lambda_invocation.CloudGuardAWPSnapshotsUtilsCleanupFunctionInvocation_inAccount,
    aws_lambda_invocation.CloudGuardAWPSnapshotsUtilsCleanupFunctionInvocation_inAccountHub,
    aws_kms_alias.CloudGuardAWPKeyAlias
   ]
}

# ----- Enable CloudGuard AWP AWS Onboarding -----
resource "dome9_awp_aws_onboarding" "awp_aws_onboarding_resource" {
  cloudguard_account_id            = var.awp_cloud_account_id
  cross_account_role_name          = aws_iam_role.CloudGuardAWPCrossAccountRole.name
  awp_centralized_cloud_account_id = local.centralized_external_account_id
  cross_account_role_external_id   = local.cross_account_role_external_id
  scan_mode                        = local.scan_mode

  dynamic "agentless_account_settings" {
    for_each = var.awp_account_settings_aws != null ? [var.awp_account_settings_aws] : []
    content {
      disabled_regions                = agentless_account_settings.value.disabled_regions
      scan_machine_interval_in_hours  = agentless_account_settings.value.scan_machine_interval_in_hours
      max_concurrent_scans_per_region = agentless_account_settings.value.max_concurrent_scans_per_region
      custom_tags                     = agentless_account_settings.value.custom_tags
    }
  }

  depends_on = [
    aws_iam_policy_attachment.CloudGuardAWPSnapshotsUtilsLambdaExecutionRolePolicyAttachment,
    aws_iam_policy_attachment.CloudGuardAWPCrossAccountRolePolicyAttachment,
    aws_iam_role.CloudGuardAWPCrossAccountRole,
    aws_lambda_invocation.CloudGuardAWPSnapshotsUtilsCleanupFunctionInvocation_saas,
    aws_lambda_invocation.CloudGuardAWPSnapshotsUtilsCleanupFunctionInvocation_inAccount,
    aws_lambda_invocation.CloudGuardAWPSnapshotsUtilsCleanupFunctionInvocation_inAccountHub,
    aws_kms_alias.CloudGuardAWPKeyAlias,
    time_sleep.wait_for_cleanup
  ]
}
