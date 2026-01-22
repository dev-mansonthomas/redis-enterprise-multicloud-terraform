output "public-ip" {
  value = azurerm_public_ip.client-public-ip.ip_address
}

output "ssh-command" {
  description = "SSH command to connect to the bastion"
  value       = "ssh ${var.ssh_user}@${azurerm_public_ip.client-public-ip.ip_address}"
}

output "prometheus-endpoint" {
  value = "http://${azurerm_public_ip.client-public-ip.ip_address}:9090"
}

output "grafana-endpoint" {
  value = "http://${azurerm_public_ip.client-public-ip.ip_address}:3000"
}

output "redisinsight-endpoint" {
  value = "http://${azurerm_public_ip.client-public-ip.ip_address}:5540"
}