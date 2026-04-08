# TechCorp AWS Infrastructure — Terraform Assessment

## Architecture Summary

```
Internet
    │
    ▼
[Internet Gateway]
    │
    ├─── Public Subnet 1 (10.0.1.0/24, us-east-1a)
    │       ├── Bastion Host (Elastic IP)
    │       └── NAT Gateway 1
    │
    ├─── Public Subnet 2 (10.0.2.0/24, us-east-1b)
    │       └── NAT Gateway 2
    │
    └─── [Application Load Balancer] (spans both public subnets)
              │
              ├─── Private Subnet 1 (10.0.3.0/24, us-east-1a)
              │       ├── Web Server 1  ◄── ALB target
              │       └── DB Server     (Postgres, private only)
              │
              └─── Private Subnet 2 (10.0.4.0/24, us-east-1b)
                      └── Web Server 2  ◄── ALB target
```

**Key security boundaries:**
- Web and DB servers have no public IPs; all inbound traffic flows via ALB or bastion.
- Bastion only accepts SSH from your admin IP.
- DB server only accepts Postgres (5432) from the web security group and SSH from the bastion.
- Private subnets reach the internet outbound through NAT gateways.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| AWS account | With programmatic access configured (`aws configure`) |
| Terraform ≥ 1.3 | `brew install terraform` or download from terraform.io |
| AWS CLI v2 | `brew install awscli` |
| EC2 key pair | Create one in the AWS console or with `aws ec2 create-key-pair` |
| Your public IP | Run `curl -s ifconfig.me` |

---

## Deployment Steps

### 1. Clone and enter the directory

```bash
git clone https://github.com/yuwa619/month-one-assessment.git
cd month-one-assessment/terraform-assessment
```

### 2. Create your variables file

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your real values:

```hcl
region        = "us-east-1"
admin_ip      = "YOUR.PUBLIC.IP.HERE"   # curl -s ifconfig.me
key_pair_name = "your-key-pair-name"
```

### 3. Initialise Terraform

```bash
terraform init
```

### 4. Review the plan

```bash
terraform plan
```


### 5. Apply (deploy the infrastructure)

```bash
terraform apply
```

Type `yes` when prompted. Deployment takes about 3–5 minutes.  

After apply, note the outputs printed to your terminal:
- `alb_dns_name` — paste this in a browser to reach the web app
- `bastion_public_ip` — use this to SSH into the bastion
- `web_server_1_private_ip` / `web_server_2_private_ip`
- `database_private_ip`

---

## Validation Steps

### Access the web application via ALB

```bash
curl http://<alb_dns_name>
# Or open it in a browser — you should see the TechCorp web page
```

Refresh a few times; you will see responses from both web servers (different instance IDs).

### SSH through the bastion to a web server

```bash
# Step 1 — SSH into the bastion
ssh -i ~/.ssh/your-key.pem ec2-user@<bastion_public_ip>

# Step 2 — From the bastion, SSH to a web server using password auth
ssh ec2-user@<web_server_1_private_ip>
# Password: WebServer2024!
```

### SSH through the bastion to the DB server

```bash
# From the bastion
ssh ec2-user@<database_private_ip>
# Password: DBServer2024!
```

### Connect to PostgreSQL on the DB server

```bash
# Once logged in to the DB server
psql -U techcorp -d techcorp_db -h localhost
# Password: TechCorp2024!

# Verify connection
\l          -- list databases
\conninfo   -- show connection details
\q          -- quit
```

---


---

## Destroy / Cleanup

When you are done and want to delete all resources to avoid AWS charges:

```bash
terraform destroy
```

Type `yes` when prompted. This removes **all** resources created by this configuration.

> **Note:** The NAT gateways and Elastic IPs are the most expensive components. If you want to stop charges quickly, run `terraform destroy` as soon as you have taken all your evidence screenshots.

---

## Assumptions

1. The AWS region defaults to `us-east-1`. Override with `region` in `terraform.tfvars`.
2. Availability zones are derived as `<region>a` and `<region>b`. This works for all standard AWS regions.
3. An EC2 key pair must exist in your account before running `terraform apply`. Create it in the AWS Console under EC2 → Key Pairs, then set `key_pair_name` in your tfvars.
4. Password authentication is enabled on all instances via the user data scripts to satisfy the assessment requirement for bastion → server access. The passwords set are defaults for demonstration only — change them immediately in a real environment.
5. The DB server is placed in `private_1` (same AZ as web server 1). This keeps things simple while remaining private and secure.
6. The ALB security group (`techcorp-alb-sg`) is separate from the web security group so the ALB can forward traffic to the web instances without conflicting rules.
