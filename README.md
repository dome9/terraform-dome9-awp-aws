# Dome9 Terraform Module - AWP Onboarding for AWS

This Terraform module is designed to onboard AWS accounts to Dome9 AWP (Advanced Workload Protection) service.

## Usage

## Variables

The following variables are used in this Terraform module:

- `awp_cross_account_role_name` (string): AWP Cross account role name. Default is `null`.
- `awp_cross_account_role_external_id` (string): AWP Cross account role external id. Default is `null`.
- `awp_resource_name_prefix` (string): Resource name prefix. Default is `""` (No prefix).
- `awp_account_settings_aws` (object): AWS Cloud Account settings. It is an object that can have the following properties:
  - `disabled_regions` (list of strings): List of regions to disable scanning. For example: `["us-east-1", "us-west-2"]`. Default is `null`.
  - `scan_machine_interval_in_hours` (number): Scan machine interval in hours. Default is `null`.
  - `max_concurrence_scans_per_region` (number): Maximum concurrence scans per region. Default is `null`.
  - `custom_tags` (map of strings): Custom tags to be added to AWP resources. For example: `{"key1" = "value1", "key2" = "value2"}`. Default is `null`.