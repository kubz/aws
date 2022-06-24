output "instance_id" {
  value = aws_instance.example.id
}

output "public_ip" {
  value = aws_instance.example.public_ip
}

output "ssh_keypair" {
  value     = tls_private_key.key.private_key_pem
  sensitive = true
}
output "key_name" {
  value = aws_key_pair.key_pair.key_name
}
