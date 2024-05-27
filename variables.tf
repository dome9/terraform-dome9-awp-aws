variable "awp_cloud_account_id" {
  description = "CLOUDGUARD_ACCOUNT_ID or EXTERNAL_AWS_ACCOUNT_NUMBER"
  type        = string
}

variable "awp_hub_external_account_id" {
  description = "centralized account EXTERNAL_AWS_ACCOUNT_NUMBER"
  type        = string
  default     = null
}

variable "awp_organization_id" {
  description = "The AWS organization id in case of centralized account, AWP use it to restrict scanning accounts that belongs to the organization"
  type        = string
  default     = ""
}

variable "awp_scan_mode" {
  description = "AWP scan mode <inAccount|saas>" # the valid values are "inAccount" and "saas" when onboarding the AWS account to Dome9 AWP.
  type        = string
  default     = "inAccount"
}

variable "awp_cross_account_role_name" {
  description = "AWP Cross account role name"
  type        = string
  default     = "CloudGuardAWPCrossAccountRole"
}

variable "awp_cross_account_role_external_id" {
  description = "AWP Cross account role external id"
  type        = string
  default     = null
}

variable "awp_additional_tags" {
  description = "Additional tags to be added to the module resources"
  type        = map(string)
  default     = {}
}

variable "awp_account_settings_aws" {
  description = "AWS Cloud Account settings"
  type = object({
    disabled_regions                = optional(list(string)) # List of regions to disable scanning e.g. ["us-east-1", "us-west-2"]
    scan_machine_interval_in_hours  = optional(number)       # Scan machine interval in hours
    max_concurrent_scans_per_region = optional(number)       # Maximum concurrence scans per region
    custom_tags                     = optional(map(string))  # Custom tags to be added to AWP resources e.g. {"key1" = "value1", "key2" = "value2"}
  })
  default = null
}