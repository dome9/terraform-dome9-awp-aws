
# This module block is used to configure the Terraform Dome9 AWP AWS module.
module "terraform-dome9-awp-aws" {
    source = "/dome9/awp/aws"

    # The ID of the Dome9 AWS Cloud Account to associate with the AWP.
    # This can be either the ID of the Dome9 Cloud Account resource or the AWS Account Number.
    awp_cloud_account_id = "012345678912"

    # The scan mode for the AWP. Valid values are "inAccount" or "saas".
    awp_scan_mode = "inAccount"
}
