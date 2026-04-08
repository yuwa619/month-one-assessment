#!/bin/bash
set -e

# Update all packages
yum update -y

# Install Apache HTTP Server
yum install -y httpd

# Enable and start Apache
systemctl enable httpd
systemctl start httpd

# Enable password-based SSH (for bastion access demonstration)
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

# Set a known password for ec2-user (change this after deployment)
echo "ec2-user:WebServer2024!" | chpasswd

# Retrieve instance metadata from IMDSv1
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/local-hostname)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Create a simple HTML page that displays instance info
cat > /var/www/html/index.html <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>TechCorp Web Server</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      background-color: #f0f4f8;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      margin: 0;
    }
    .card {
      background: white;
      border-radius: 10px;
      padding: 40px 50px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.1);
      max-width: 560px;
      width: 100%;
    }
    h1 { color: #2c3e50; margin-top: 0; }
    .badge {
      display: inline-block;
      background: #3498db;
      color: white;
      padding: 4px 10px;
      border-radius: 12px;
      font-size: 0.85em;
      margin-bottom: 20px;
    }
    table { width: 100%; border-collapse: collapse; }
    td { padding: 10px 8px; border-bottom: 1px solid #ecf0f1; }
    td:first-child { font-weight: bold; color: #555; width: 40%; }
    td:last-child { font-family: monospace; color: #2c3e50; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">TechCorp Infrastructure</div>
    <h1>Web Server Online</h1>
    <table>
      <tr><td>Instance ID</td><td>${INSTANCE_ID}</td></tr>
      <tr><td>Hostname</td><td>${HOSTNAME}</td></tr>
      <tr><td>Private IP</td><td>${PRIVATE_IP}</td></tr>
      <tr><td>Availability Zone</td><td>${AZ}</td></tr>
    </table>
  </div>
</body>
</html>
HTML

# Restart Apache to make sure everything is clean
systemctl restart httpd
