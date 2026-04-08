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

