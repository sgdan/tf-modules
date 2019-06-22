# nat-instance

Terraform module which creates a NAT instance for a VPC:

- Runs in public subnet
- `t2.micro` instance type so free tier eligible
- Cheaper than NAT gateway, good for simple testing
