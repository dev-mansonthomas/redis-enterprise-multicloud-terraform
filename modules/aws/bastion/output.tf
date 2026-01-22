output "public-ip" {
  value = aws_eip.eip.public_ip
}

output "ssh-command" {
  description = "SSH command to connect to the bastion"
  value       = "ssh ${var.ssh_user}@${aws_eip.eip.public_ip}"
}

output "prometheus-endpoint" {
  value = "http://${aws_eip.eip.public_ip}:9090"
}

output "grafana-endpoint" {
  value = "http://${aws_eip.eip.public_ip}:3000"
}

output "redisinsight-endpoint" {
  value = "http://${aws_eip.eip.public_ip}:5540"
}