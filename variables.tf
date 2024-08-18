variable "awp_cloud_account_id" {
  description = "CLOUDGUARD_ACCOUNT_ID or EXTERNAL_AWS_ACCOUNT_NUMBER"
  type        = string
}

variable "awp_centralized_cloud_account_id" {
  description = "CENTRALIZED_CLOUDGUARD_ACCOUNT_ID or CENTRALIZED_EXTERNAL_AWS_ACCOUNT_NUMBER"
  type        = string
  default     = null
}

variable "awp_scan_mode" {
  description = "AWP scan mode, possible values are: <inAccount | saas | inAccountHub | inAccountSub>"
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
    in_account_scanner_vpc          = optional(string)       # The VPC Mode. Valid values: "ManagedByAWP", "ManagedByCustomer"
    custom_tags                     = optional(map(string))  # Custom tags to be added to AWP resources e.g. {"key1" = "value1", "key2" = "value2"}
  })
  default = {}
}