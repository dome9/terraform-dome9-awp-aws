#!/bin/bash
# This script is used to generate the README.md file with the terraform-docs tool

# Header
terraform-docs markdown table \
--output-file README.md \
--output-mode inject \
--output-template '<!-- BEGIN_TF_HEADER_DOCS -->\n{{ .Content }}\n<!-- END_TF_HEADER_DOCS -->' \
--show header,requirements  ./ 

# Resources
terraform-docs markdown table \
--output-file README.md \
--output-mode inject \
--show resources,outputs ./