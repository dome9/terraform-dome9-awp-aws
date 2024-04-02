data "dome9_cloudaccount_aws" "cloud_account" {
  id = var.awp_cloud_account_id
}

# The data source retrieves the onboarding data of an AWS account in Dome9 AWP.
data "dome9_awp_aws_onboarding_data" "dome9_awp_aws_onboarding_data_source" {
  cloud_account_id = data.dome9_cloudaccount_aws.cloud_account.id
}

# Define local values used in multiple places in the configuration.
locals {
  awp_module_version = "7"
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
}

# This Terraform file defines the configuration for creating an IAM role that allows CloudGuard access to the AWS account.

# The `data "aws_partition" "current"` block retrieves information about the current AWS partition.
data "aws_partition" "current" {}

# The `data "aws_region" "current"` block retrieves information about the current AWS region.
data "aws_region" "current" {}

# The `data "aws_caller_identity" "current"` block retrieves information about the current AWS caller identity.
data "aws_caller_identity" "current" {}

# The `resource "aws_iam_role" "CloudGuardAWPCrossAccountRole"` block defines an IAM role that is used to allow CloudGuard AWP to access the AWS account.
resource "aws_iam_role" "CloudGuardAWPCrossAccountRole" {
  name        = var.awp_cross_account_role_name
  description = "CloudGuard AWP Cross Account Role"

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

  tags = {
    Owner = "CG.AWP"
    "CG.AL.TF.MODULE_VERSION" = local.awp_module_version
  }

  # The `depends_on` attribute specifies that this IAM role depends on the `aws_lambda_function.CloudGuardAWPSnapshotsUtilsFunction` resource.
  depends_on = [aws_lambda_function.CloudGuardAWPSnapshotsUtilsFunction]
}

## CloudGuard AWP Resources ##

// Note: count - Used as condition to create resources based on the scan mode.

# The CloudGuardAWPCrossAccountRolePolicy resource defines an IAM policy that is used to define the permissions for the CloudGuardAWPCrossAccountRole.
resource "aws_iam_policy" "CloudGuardAWP" {
  name        = "CloudGuardAWP"
  description = "Policy for CloudGuard AWP"

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
      },
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
        Resource = aws_lambda_function.CloudGuardAWPSnapshotsUtilsFunction.arn
      },
      {
        Effect = "Allow",
        Action=  "iam:ListRoleTags",
        Resource = aws_iam_role.CloudGuardAWPCrossAccountRole.arn 
      },
      {
        Effect   = "Allow"
        Action   = "cloudformation:DescribeStacks"
        Resource = "arn:${data.aws_partition.current.partition}:cloudformation:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stack/*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "arn:${data.aws_partition.current.partition}:s3:::${local.agentless_bucket_name}/${local.remote_functions_prefix_key}*"
      }
    ]
  })
}

# The CloudGuardAWPCrossAccountRoleAttachment resource attaches the CloudGuardAWPCrossAccountRolePolicy to the CloudGuardAWPCrossAccountRole.
resource "aws_iam_role_policy_attachment" "CloudGuardAWPCrossAccountRoleAttachment" {
  role       = aws_iam_role.CloudGuardAWPCrossAccountRole.name
  policy_arn = aws_iam_policy.CloudGuardAWP.arn
}
# end resources for CloudGuardAWPCrossAccountRole

# Cross account role policy
# The CloudGuardAWPCrossAccountRolePolicy resource defines an IAM policy that is used to define the permissions for the CloudGuardAWPCrossAccountRole.
resource "aws_iam_policy" "CloudGuardAWPCrossAccountRolePolicy_InAccount" {
  count       = local.scan_mode == "inAccount" ? 1 : 0
  name        = "CloudGuardAWPCrossAccountRolePolicy_InAccount"
  description = "Policy for CloudGuard AWP Cross Account Role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSecurityGroup",
          "ec2:DescribeManagedPrefixLists",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSecurityGroupRules",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:CreateTags",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteSecurityGroup",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Owner" = "CG.AWP"
          }
        }
      },
    ]
  })
}

# The CloudGuardAWPCrossAccountRolePolicy_SaaS resource defines an IAM policy that is used to define the permissions for the CloudGuardAWPCrossAccountRole in SaaS mode.
resource "aws_iam_policy" "CloudGuardAWPCrossAccountRolePolicy_SaaS" {
  count       = local.scan_mode == "saas" ? 1 : 0
  name        = "CloudGuardAWPCrossAccountRolePolicy_SaaS"
  description = "Policy for CloudGuard AWP Cross Account Role - SaaS Mode"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:DescribeKey",
          "kms:ReplicateKey",
        ]
        Resource = [aws_kms_key.CloudGuardAWPKey[count.index].arn]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:PutKeyPolicy",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion",
          "kms:TagResource",
        ]
        Resource = aws_kms_key.CloudGuardAWPKey[count.index].arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:CreateKey",
        ]
        Resource = "*"
      },
    ]
  })
}

# The CloudGuardAWPCrossAccountRolePolicyAttachment resource attaches the CloudGuardAWPCrossAccountRolePolicy to the CloudGuardAWPCrossAccountRole.
resource "aws_iam_policy_attachment" "CloudGuardAWPCrossAccountRolePolicyAttachment" {
  count      = local.scan_mode == "inAccount" ? 1 : 0
  name       = "CloudGuardAWPCrossAccountRolePolicyAttachment"
  policy_arn = aws_iam_policy.CloudGuardAWPCrossAccountRolePolicy_InAccount[count.index].arn
  roles      = [aws_iam_role.CloudGuardAWPCrossAccountRole.name]
}

# The CloudGuardAWPCrossAccountRolePolicyAttachment_SaaS resource attaches the CloudGuardAWPCrossAccountRolePolicy_SaaS to the CloudGuardAWPCrossAccountRole.
resource "aws_iam_policy_attachment" "CloudGuardAWPCrossAccountRolePolicyAttachment_SaaS" {
  count      = local.scan_mode == "saas" ? 1 : 0
  name       = "CloudGuardAWPCrossAccountRolePolicyAttachment_SaaS"
  policy_arn = aws_iam_policy.CloudGuardAWPCrossAccountRolePolicy_SaaS[count.index].arn
  roles      = [aws_iam_role.CloudGuardAWPCrossAccountRole.name]
}
# END Cross account role policy

# The CloudGuardAWPSnapshotsUtilsFunctionZip resource defines http data source to download the remote function file from S3 pre-signed URL.
data "http" "CloudGuardAWPSnapshotsUtilsFunctionZip" {
  url    = local.remote_snapshots_utils_function_s3_pre_signed_url
  method = "GET"
  request_headers = {
    Accept = "application/zip"
    Accept-Ranges = "bytes"
  }
}

# The CloudGuardAWPSnapshotsUtilsFunctionZip resource defines a local file that is used to store the remote function file to be used in the lambda function.
resource "local_file" "CloudGuardAWPSnapshotsUtilsFunctionZip" {
  filename       = "${local.remote_snapshots_utils_function_name}.zip"
  content_base64 = data.http.CloudGuardAWPSnapshotsUtilsFunctionZip.response_body_base64
}

# AWP proxy lambda function
# The CloudGuardAWPSnapshotsUtilsFunction resource defines a lambda function that is used to manage remote actions and resources.
resource "aws_lambda_function" "CloudGuardAWPSnapshotsUtilsFunction" {
  function_name = local.remote_snapshots_utils_function_name ## TBD allow adding a prefix
  handler       = "snapshots_utils.lambda_handler"
  description   = "CloudGuard AWP Proxy for managing remote actions and resources"
  role          = aws_iam_role.CloudGuardAWPSnapshotsUtilsLambdaExecutionRole.arn
  runtime       = "python3.9"
  memory_size   = 256
  timeout       = local.remote_snapshots_utils_function_time_out
  filename      = local_file.CloudGuardAWPSnapshotsUtilsFunctionZip.filename

  environment {
    variables = {
      CP_AWP_AWS_ACCOUNT         = local.cloud_guard_backend_account_id
      CP_AWP_MR_KMS_KEY_ID       = local.scan_mode == "saas" ? aws_kms_key.CloudGuardAWPKey[0].arn : ""
      CP_AWP_SCAN_MODE           = local.scan_mode
      CP_AWP_SECURITY_GROUP_NAME = local.awp_client_side_security_group_name
      AWS_PARTITION              = data.aws_partition.current.partition
    }
  }

  tags = {
    Owner = "CG.AWP"
    "CG.AL.TF.MODULE_VERSION" = local.awp_module_version
  }
}

resource "aws_lambda_permission" "allow_cloudguard" {
  statement_id  = "AllowExecutionFromCloudGuard"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.CloudGuardAWPSnapshotsUtilsFunction.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:${data.aws_partition.current.partition}:s3:::${local.agentless_bucket_name}/*"
}
# END AWP proxy lambda function

# CloudGuardAWPSnapshotsUtilsLogGroup : The CloudWatch log group that is used to store the logs of the CloudGuardAWPSnapshotsUtilsFunction.
resource "aws_cloudwatch_log_group" "CloudGuardAWPSnapshotsUtilsLogGroup" {
  name              = "/aws/lambda/${aws_lambda_function.CloudGuardAWPSnapshotsUtilsFunction.function_name}"
  retention_in_days = 30
  depends_on = [
    aws_lambda_function.CloudGuardAWPSnapshotsUtilsFunction
  ]
  tags = {
    Owner = "CG.AWP"
    "CG.AL.TF.MODULE_VERSION" = local.awp_module_version
  }
}

# AWP proxy lambda function role
# The CloudGuardAWPSnapshotsUtilsLambdaExecutionRole resource defines an IAM role that is used to allow the CloudGuardAWPSnapshotsUtilsFunction to execute.
resource "aws_iam_role" "CloudGuardAWPSnapshotsUtilsLambdaExecutionRole" {
  name        = "CloudGuardAWPLambdaExecutionRole"
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

  tags = {
    Owner = "CG.AWP"
    "CG.AL.TF.MODULE_VERSION" = local.awp_module_version
  }
}

# The CloudGuardAWPSnapshotsPolicy resource defines an IAM policy that is used to define the permissions for the CloudGuardAWPSnapshotsUtilsFunction.
resource "aws_iam_policy" "CloudGuardAWPSnapshotsPolicy" {
  name        = "CloudGuardAWPSnapshotsPolicy"
  description = "Policy for managing snapshots at client side and delete AWP keys"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:CopySnapshot",
          "ec2:CreateSnapshot",
          "ec2:CreateSnapshots",
          "ec2:DescribeSnapshots",
          "ec2:DescribeRegions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteSnapshot"
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
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [aws_cloudwatch_log_group.CloudGuardAWPSnapshotsUtilsLogGroup.arn]
      }
    ]
  })
}

# The CloudGuardAWPSnapshotsUtilsLambdaExecutionRoleAttachment resource attaches the CloudGuardAWPSnapshotsPolicy to the CloudGuardAWPSnapshotsUtilsLambdaExecutionRole.
resource "aws_iam_role_policy_attachment" "CloudGuardAWPSnapshotsUtilsLambdaExecutionRoleAttachment" {
  role       = aws_iam_role.CloudGuardAWPSnapshotsUtilsLambdaExecutionRole.name
  policy_arn = aws_iam_policy.CloudGuardAWPSnapshotsPolicy.arn
}
# END AWP proxy lambda function role

# AWP proxy lambda function role policy
# The CloudGuardAWPLambdaExecutionRolePolicy resource defines an IAM policy that is used to define the permissions for the CloudGuardAWPSnapshotsUtilsFunction.
resource "aws_iam_policy" "CloudGuardAWPLambdaExecutionRolePolicy" {
  count       = local.scan_mode == "inAccount" ? 1 : 0
  name        = "CloudGuardAWPLambdaExecutionRolePolicy"
  description = "Policy for CloudGuard AWP Lambda Execution Role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:TerminateInstances",
          "ec2:DeleteVolume",
        ]
        Resource = "*"
        Condition = local.scan_mode == "inAccount" ? {
          StringEquals = {
            "aws:ResourceTag/Owner" = "CG.AWP"
          }
        } : null
      },
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole",
        ]
        Resource = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot"]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:Encrypt",
          "kms:ReEncrypt*",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc",
          "ec2:CreateSecurityGroup",
          "ec2:CreateSubnet",
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeRouteTables",
          "ec2:DescribeNetworkAcls",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeSecurityGroupRules",
          "ec2:ModifySubnetAttribute",
          "ec2:CreateVpcEndpoint",
          "ec2:DescribeVpcEndpoints",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
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
          "ec2:CreateNetworkAclEntry",
        ]
        Resource = "*"
        Condition = local.scan_mode == "inAccount" ? {
          StringEquals = {
            "aws:ResourceTag/Owner" = "CG.AWP"
          }
        } : null
      },
    ]
  })
  
}

# The CloudGuardAWPLambdaExecutionRolePolicyAttachment resource attaches the CloudGuardAWPLambdaExecutionRolePolicy to the CloudGuardAWPSnapshotsUtilsLambdaExecutionRole.
resource "aws_iam_policy" "CloudGuardAWPLambdaExecutionRolePolicy_SaaS" {
  count       = local.scan_mode == "saas" ? 1 : 0
  name        = "CloudGuardAWPLambdaExecutionRolePolicy_SaaS"
  description = "Policy for CloudGuard AWP Lambda Execution Role - SaaS Mode"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:ModifySnapshotAttribute",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:ReEncrypt*",
          "kms:Encrypt",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:ScheduleKeyDeletion",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Owner" = "CG.AWP"
          }
        }
      },
    ]
  })
}

# The CloudGuardAWPLambdaExecutionRolePolicyAttachment resource attaches the CloudGuardAWPLambdaExecutionRolePolicy to the CloudGuardAWPSnapshotsUtilsLambdaExecutionRole.
resource "aws_iam_policy_attachment" "CloudGuardAWPLambdaExecutionRolePolicyAttachment_InAccount" {
  count      = local.scan_mode == "inAccount" ? 1 : 0
  name       = "CloudGuardAWPLambdaExecutionRolePolicyAttachmentInAccount"
  policy_arn = aws_iam_policy.CloudGuardAWPLambdaExecutionRolePolicy[count.index].arn
  roles      = [aws_iam_role.CloudGuardAWPSnapshotsUtilsLambdaExecutionRole.name]
}

# The CloudGuardAWPLambdaExecutionRolePolicyAttachment_SaaS resource attaches the CloudGuardAWPLambdaExecutionRolePolicy_SaaS to the CloudGuardAWPSnapshotsUtilsLambdaExecutionRole.
resource "aws_iam_policy_attachment" "CloudGuardAWPLambdaExecutionRolePolicyAttachment_SaaS" {
  count      = local.scan_mode == "saas" ? 1 : 0
  name       = "CloudGuardAWPLambdaExecutionRolePolicyAttachmentSaas"
  policy_arn = aws_iam_policy.CloudGuardAWPLambdaExecutionRolePolicy_SaaS[count.index].arn
  roles      = [aws_iam_role.CloudGuardAWPSnapshotsUtilsLambdaExecutionRole.name]
}
# END AWP proxy lambda function role policy

# aws_lambda_invocation : The Lambda invocation that is used to clean up the resources after the onboarding process.
resource "aws_lambda_invocation" "CloudGuardAWPSnapshotsUtilsCleanupFunctionInvocation_InAccount" {
  function_name = aws_lambda_function.CloudGuardAWPSnapshotsUtilsFunction.function_name
  input = jsonencode({
    "target_account_id" : data.dome9_awp_aws_onboarding_data.dome9_awp_aws_onboarding_data_source.cloud_account_id
  })
  lifecycle_scope = "CRUD"
  count                   = local.scan_mode == "inAccount" ? 1 : 0
  depends_on = [
    aws_iam_policy_attachment.CloudGuardAWPLambdaExecutionRolePolicyAttachment_InAccount,
    aws_iam_policy_attachment.CloudGuardAWPLambdaExecutionRolePolicyAttachment_SaaS,
    aws_cloudwatch_log_group.CloudGuardAWPSnapshotsUtilsLogGroup
  ]
}

resource "aws_lambda_invocation" "CloudGuardAWPSnapshotsUtilsCleanupFunctionInvocation_SaaS" {
  function_name = aws_lambda_function.CloudGuardAWPSnapshotsUtilsFunction.function_name
  input = jsonencode({
    "target_account_id" : data.dome9_awp_aws_onboarding_data.dome9_awp_aws_onboarding_data_source.cloud_account_id
  })
  count                   = local.scan_mode == "saas" ? 1 : 0
  lifecycle_scope = "CRUD"
  depends_on = [
    aws_iam_policy_attachment.CloudGuardAWPLambdaExecutionRolePolicyAttachment_InAccount,
    aws_iam_policy_attachment.CloudGuardAWPLambdaExecutionRolePolicyAttachment_SaaS,
    aws_cloudwatch_log_group.CloudGuardAWPSnapshotsUtilsLogGroup
  ]
}

# AWP MR key for snapshot re-encryption
# The CloudGuardAWPKey resource defines a KMS key that is used to re-encrypt the snapshots in SaaS mode.
resource "aws_kms_key" "CloudGuardAWPKey" {
  count                   = local.scan_mode == "saas" ? 1 : 0
  description             = "CloudGuard AWP Multi-Region primary key for snapshots re-encryption (for Saas mode only)"
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
        Sid    = "Allow usage of the key"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${local.cloud_guard_backend_account_id}:root"
        }
        Action = [
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:PutKeyPolicy",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion",
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow attachment of persistent resources"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${local.cloud_guard_backend_account_id}:root"
        }
        Action = [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant",
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" = true
          }
        }
      },
    ]
  })
  tags = {
    Owner = "CG.AWP"
    "CG.AL.TF.MODULE_VERSION" = local.awp_module_version
  }
}
#END AWP MR key for snapshot re-encryption

# The CloudGuardAWPKeyAlias resource defines a KMS key alias that is used to reference the KMS key in SaaS mode.
resource "aws_kms_alias" "CloudGuardAWPKeyAlias" {
  count         = local.scan_mode == "saas" ? 1 : 0
  name          = "alias/CloudGuardAWPKey"
  target_key_id = aws_kms_key.CloudGuardAWPKey[count.index].arn
  depends_on = [
    aws_kms_key.CloudGuardAWPKey
  ]
}
# #---# Enable CloudGuard AWP #---#
resource "dome9_awp_aws_onboarding" "awp_aws_onboarding_resource" {
  cloudguard_account_id          = var.awp_cloud_account_id
  cross_account_role_name        = aws_iam_role.CloudGuardAWPCrossAccountRole.name
  cross_account_role_external_id = local.cross_account_role_external_id
  scan_mode                      = local.scan_mode


  agentless_account_settings {
    disabled_regions                 = var.awp_account_settings_aws.disabled_regions 
    scan_machine_interval_in_hours   = var.awp_account_settings_aws.scan_machine_interval_in_hours
    max_concurrent_scans_per_region = var.awp_account_settings_aws.max_concurrent_scans_per_region
    custom_tags                      = var.awp_account_settings_aws.custom_tags
  }

  depends_on = [
    aws_iam_policy_attachment.CloudGuardAWPLambdaExecutionRolePolicyAttachment_InAccount,
    aws_iam_policy_attachment.CloudGuardAWPLambdaExecutionRolePolicyAttachment_SaaS,
    aws_iam_role.CloudGuardAWPCrossAccountRole,
    aws_iam_role_policy_attachment.CloudGuardAWPCrossAccountRoleAttachment,
    aws_lambda_invocation.CloudGuardAWPSnapshotsUtilsCleanupFunctionInvocation_InAccount,
    aws_lambda_invocation.CloudGuardAWPSnapshotsUtilsCleanupFunctionInvocation_SaaS,
    aws_kms_alias.CloudGuardAWPKeyAlias
   ]
}
