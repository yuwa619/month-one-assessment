#!/bin/bash
set -e

# Update all packages
yum update -y

# Enable PostgreSQL 14 from Amazon Linux Extras and install
amazon-linux-extras enable postgresql14
yum install -y postgresql-server postgresql

# Initialise the database cluster
postgresql-setup initdb

# ── pg_hba.conf: allow md5 password auth from within the VPC ──────────────────
# Replace the default ident lines so VPC-local connections use passwords.
sed -i \
  's|host    all             all             127.0.0.1/32            ident|host    all             all             10.0.0.0/16             md5|g' \
  /var/lib/pgsql/data/pg_hba.conf

sed -i \
  's|host    all             all             ::1/128                 ident|host    all             all             ::1/128                 md5|g' \
  /var/lib/pgsql/data/pg_hba.conf

# ── postgresql.conf: listen on all interfaces inside the VPC ──────────────────
sed -i \
  "s|#listen_addresses = 'localhost'|listen_addresses = '*'|g" \
  /var/lib/pgsql/data/postgresql.conf

# Enable and start PostgreSQL
systemctl enable postgresql
systemctl start postgresql

# Create application database and user
sudo -u postgres psql <<SQL
CREATE USER techcorp WITH PASSWORD 'TechCorp2024!';
CREATE DATABASE techcorp_db OWNER techcorp;
GRANT ALL PRIVILEGES ON DATABASE techcorp_db TO techcorp;
SQL

# Enable password-based SSH (for bastion access demonstration)
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

# Set a known password for ec2-user (change this after deployment)
echo "ec2-user:DBServer2024!" | chpasswd
