output "resource_group_name" {
  description = "The name of the resource group."
  value       = azurerm_resource_group.rg.name
}

output "host_pool_id" {
  description = "The ID of the AVD Host Pool."
  value       = module.avd_host_pool.resource.id
}

output "workspace_id" {
  description = "The ID of the AVD Workspace."
  value       = module.avd_workspace.resource.id
}

output "vm_name" {
  description = "The name of the session host VM."
  value       = azurerm_windows_virtual_machine.vm.name
}

output "private_ip_address" {
  description = "The private IP address of the session host VM."
  value       = azurerm_network_interface.nic.private_ip_address
}

output "admin_password" {
  description = "The generated admin password for the session host VM."
  value       = random_password.admin_password.result
  sensitive   = true
} 