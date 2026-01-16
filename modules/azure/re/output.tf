output "re-nodes" {
  description = "The Redis Enterprise nodes (master + workers)"
  value       = concat([azurerm_linux_virtual_machine.cluster_master], azurerm_linux_virtual_machine.nodes)
}

output "re-public-ips" {
  description = "Public IP addresses of all Redis cluster nodes"
  value       = concat(
    [azurerm_linux_virtual_machine.cluster_master.public_ip_address],
    azurerm_linux_virtual_machine.nodes[*].public_ip_address
  )
}

output "re-private-ips" {
  description = "Private IP addresses of all Redis cluster nodes"
  value       = concat(
    [azurerm_linux_virtual_machine.cluster_master.private_ip_address],
    azurerm_linux_virtual_machine.nodes[*].private_ip_address
  )
}

output "re-master-ip" {
  description = "Private IP address of the master node"
  value       = azurerm_network_interface.master-nic.private_ip_address
}