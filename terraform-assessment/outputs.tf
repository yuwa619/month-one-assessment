output "vpc_id" {
  description = "ID of the TechCorp VPC"
  value       = aws_vpc.main.id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer — paste this in a browser to reach the web app"
  value       = aws_lb.main.dns_name
}

output "bastion_public_ip" {
  description = "Public Elastic IP of the bastion host"
  value       = aws_eip.bastion.public_ip
}

output "web_server_1_private_ip" {
  description = "Private IP of web server 1 (us for SSH via bastion)"
  value       = aws_instance.web_1.private_ip
}

output "web_server_2_private_ip" {
  description = "Private IP of web server 2 (use for SSH via bastion)"
  value       = aws_instance.web_2.private_ip
}

output "database_private_ip" {
  description = "Private IP of the database server (use for SSH via bastion)"
  value       = aws_instance.database.private_ip
}
