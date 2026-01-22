output "public-ip" {
  value = google_compute_address.bastion-ip-address.address
}

output "ssh-command" {
  description = "SSH command to connect to the bastion"
  value       = "ssh ${var.ssh_user}@${google_compute_address.bastion-ip-address.address}"
}

output "prometheus-endpoint" {
  value = "http://${google_compute_address.bastion-ip-address.address}:9090"
}

output "grafana-endpoint" {
  value = "http://${google_compute_address.bastion-ip-address.address}:3000"
}

output "redisinsight-endpoint" {
  value = "http://${google_compute_address.bastion-ip-address.address}:5540"
}