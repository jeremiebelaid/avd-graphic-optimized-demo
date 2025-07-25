variable "prefix" {
  description = "A prefix to be added to all resource names."
  type        = string
  default     = "avd-nv4"
}

variable "location" {
  description = "The Azure region where to create the resources."
  type        = string
  default     = "West Europe"
}

variable "resource_group_name" {
  description = "The name of the resource group."
  type        = string
  default     = "" # If empty, a name will be generated using the prefix
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default = {
    "Project"     = "AVD Deployment"
    "Environment" = "Terraform-Demo"
  }
}

variable "vnet_address_space" {
  description = "The address space for the Virtual Network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_address_prefix" {
  description = "The address prefix for the Subnet."
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "admin_username" {
  description = "The admin username for the session host VM."
  type        = string
  default     = "avdadmin"
}

variable "vm_size" {
  description = "The size of the session host VM."
  type        = string
  default     = "Standard_NV4as_v4"
}

variable "vm_image_publisher" {
  description = "The publisher of the VM image."
  type        = string
  default     = "MicrosoftWindowsDesktop"
}

variable "vm_image_offer" {
  description = "The offer of the VM image."
  type        = string
  default     = "windows-11"
}

variable "vm_image_sku" {
  description = "The SKU of the VM image."
  type        = string
  default     = "win11-23h2-avd"
}

variable "host_pool_name" {
  description = "The name of the AVD Host Pool."
  type        = string
  default     = "hp-avd-nv4"
}

variable "app_group_name" {
  description = "The name of the AVD Application Group."
  type        = string
  default     = "ag-desktop"
}

variable "workspace_name" {
  description = "The name of the AVD Workspace."
  type        = string
  default     = "ws-avd"
}

variable "devtools_update_trigger" {
  description = "A trigger to force re-running the devtools installation script. Change this value to force an update."
  type        = string
  default     = "1.0.0"
} 