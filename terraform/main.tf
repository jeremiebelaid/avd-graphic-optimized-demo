terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
  }
}

provider "azurerm" {
  resource_provider_registrations = "none"
  features {}
  subscription_id = "394058e8-419b-4eb4-bc98-58f37c4a0c48"
}

locals {
  resource_group_name = var.resource_group_name == "" ? "${var.prefix}-rg" : var.resource_group_name
  vnet_name           = "${var.prefix}-vnet"
  subnet_name         = "${var.prefix}-snet"
  nic_name            = "${var.prefix}-nic"
  vm_name             = "${var.prefix}-vm"
}

# Create a random password for the VM
resource "random_password" "admin_password" {
  length           = 20
  special          = true
  override_special = "_%@!"
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = local.vnet_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

# Create a subnet
resource "azurerm_subnet" "subnet" {
  name                 = local.subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.subnet_address_prefix
}

module "avd_host_pool" {
  source  = "Azure/avm-res-desktopvirtualization-hostpool/azurerm"
  version = "0.4.0"

  resource_group_name                           = azurerm_resource_group.rg.name
  virtual_desktop_host_pool_name                = var.host_pool_name
  virtual_desktop_host_pool_location            = azurerm_resource_group.rg.location
  virtual_desktop_host_pool_resource_group_name = azurerm_resource_group.rg.name
  virtual_desktop_host_pool_type                = "Pooled"
  virtual_desktop_host_pool_load_balancer_type  = "BreadthFirst"
  virtual_desktop_host_pool_tags                = var.tags
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "registration_info" {
  hostpool_id     = module.avd_host_pool.resource.id
  expiration_date = timeadd(timestamp(), "672h") # 28 days
}

module "avd_workspace" {
  source  = "Azure/avm-res-desktopvirtualization-workspace/azurerm"
  version = "0.2.2"

  virtual_desktop_workspace_name                = var.workspace_name
  virtual_desktop_workspace_location            = azurerm_resource_group.rg.location
  virtual_desktop_workspace_resource_group_name = azurerm_resource_group.rg.name
  virtual_desktop_workspace_tags                = var.tags
}

module "avd_app_group" {
  source  = "Azure/avm-res-desktopvirtualization-applicationgroup/azurerm"
  version = "0.2.1"

  virtual_desktop_application_group_name                = var.app_group_name
  virtual_desktop_application_group_location            = azurerm_resource_group.rg.location
  virtual_desktop_application_group_resource_group_name = azurerm_resource_group.rg.name
  virtual_desktop_application_group_type                = "Desktop"
  virtual_desktop_application_group_host_pool_id        = module.avd_host_pool.resource.id
  virtual_desktop_application_group_tags                = var.tags
}

# Associate the application group with the workspace
resource "azurerm_virtual_desktop_workspace_application_group_association" "ws-assoc" {
  workspace_id         = module.avd_workspace.resource.id
  application_group_id = module.avd_app_group.resource.id
}

# Get the current user's object ID
data "azurerm_client_config" "current" {}

# Assign the current user to the application group
resource "azurerm_role_assignment" "app_group_user" {
  scope                = module.avd_app_group.resource.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Assign the current user to the VM for login
resource "azurerm_role_assignment" "vm_user_login" {
  scope                = azurerm_windows_virtual_machine.vm.id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Create a network interface for the VM
resource "azurerm_network_interface" "nic" {
  name                = local.nic_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

# Create the session host virtual machine
resource "azurerm_windows_virtual_machine" "vm" {
  name                = local.vm_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = random_password.admin_password.result
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.vm_image_publisher
    offer     = var.vm_image_offer
    sku       = var.vm_image_sku
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
  
  tags = var.tags
}

resource "azurerm_virtual_machine_extension" "aad_login" {
  name                 = "AADLoginForWindows"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADLoginForWindows"
  type_handler_version = "1.0"
}

resource "azurerm_virtual_machine_extension" "amd_gpu_driver" {
  name                 = "AmdGpuDriver"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.HpcCompute"
  type                 = "AmdGpuDriverWindows"
  type_handler_version = "1.0"
}

resource "azurerm_virtual_machine_extension" "avd_agent" {
  name                       = "avd-agent-dsc"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "modulesUrl": "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02714.342.zip",
      "configurationFunction": "Configuration.ps1\\AddSessionHost",
      "properties": {
        "HostPoolName":"${module.avd_host_pool.resource.name}"
      }
    }
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
  {
    "properties": {
      "registrationInfoToken": "${azurerm_virtual_desktop_host_pool_registration_info.registration_info.token}"
    }
  }
PROTECTED_SETTINGS

  depends_on = [
    azurerm_windows_virtual_machine.vm,
    azurerm_virtual_machine_extension.aad_login,
    azurerm_virtual_machine_extension.amd_gpu_driver,
    module.avd_host_pool
  ]

}

# Install common development tools like VS Code and Cursor
resource "azurerm_virtual_machine_extension" "install_devtools" {
  name                 = "install-devtools"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  auto_upgrade_minor_version = true

  # This extension runs a PowerShell command to install or upgrade VS Code and Cursor using winget.
  # The --silent flag ensures the installation is unattended.
  # The --accept-package-agreements flag is used to automatically accept license terms.
  # The devtools_update_trigger variable is used to force re-running this script.
  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted -Command '# Trigger: ${var.devtools_update_trigger} ; winget upgrade --id Microsoft.VisualStudioCode --accept-package-agreements --silent; winget upgrade --id Anysphere.Cursor --accept-package-agreements --silent'"
    }
  SETTINGS

  depends_on = [
    azurerm_virtual_machine_extension.avd_agent
  ]
}
