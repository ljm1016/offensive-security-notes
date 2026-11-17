#cloud #aws #azure #gcp #fundamentals

Cloud penetration testing differs fundamentally from traditional network pentesting. The attack surface is configuration, not software vulnerabilities. Understanding cloud architecture, shared responsibility, and resource hierarchies is essential.

---

## What is Cloud Computing

Cloud computing delivers computing resources (compute, storage, networking, databases) over the internet on a pay-as-you-go basis instead of owning and operating physical infrastructure.

### Three Service Models

**Infrastructure as a Service (IaaS)**
- You manage: OS, applications, data
- Provider manages: hardware, networking, facilities
- Example: AWS EC2, Azure Virtual Machines, GCP Compute Engine
- **Pentesting focus:** VMs carry attached cloud identities with access to other services

**Platform as a Service (PaaS)**
- You manage: applications, data
- Provider manages: OS, runtime, middleware, hardware
- Example: AWS Lambda, Azure Functions, GCP Cloud Functions
- **Pentesting focus:** Serverless functions also carry identities; often overprivileged

**Software as a Service (SaaS)**
- You manage: your data only
- Provider manages: everything else
- Example: Salesforce, Microsoft 365, Google Workspace
- **Pentesting focus:** Less direct access, but misconfigurations in account linking/federation

---

## Shared Responsibility Model

This is critical: **the cloud provider secures the cloud; you secure what's in it.**

```
CSP Responsibility:
├─ Physical hardware
├─ Network infrastructure
├─ Facilities
└─ Hypervisor

Customer Responsibility:
├─ Data
├─ Identity & access control (IAM)
├─ Applications
├─ Configuration
└─ Network firewalls
```

**Most cloud breaches are the customer's fault**, not the provider's. CSPs will not stop you from misconfiguring your own resources.

---

## Organizational Hierarchy

### AWS
```
AWS Account (top level)
└─ Organization root
   └─ Organizational units
      └─ AWS accounts (billing, isolation, resources)
         └─ Regions (geographic location)
            └─ Availability zones (isolated data centers)
               └─ Resources (EC2, S3, etc.)
```

**Key point:** Misconfigurations at the top level trickle down to all resources below.

### Azure
```
Management groups (organize subscriptions)
└─ Subscriptions (billing, isolation)
   └─ Resource groups
      └─ Resources
         └─ Regions
```

### GCP
```
Organization
└─ Folders (grouping projects)
   └─ Projects (billing + resource boundary)
      └─ Resources
         └─ Regions
```

---

## Five Core Resource Categories

### 1. Compute
Things that run code:
- **Virtual machines:** AWS EC2, Azure VM, GCP Compute Engine
- **Serverless functions:** AWS Lambda, Azure Functions, GCP Cloud Functions
- **Containers:** ECS, AKS, GKE

**Pentesting:** Compute resources have identities (instance profiles, managed identities, service accounts). Compromise the compute = inherit its permissions.

### 2. Storage
Things that hold data:
- **Object storage:** S3, Azure Blob Storage, GCP Cloud Storage
- **Databases:** RDS, Azure SQL, Cloud SQL, DynamoDB, CosmosDB
- **Snapshots & backups:** Often left public

**Pentesting:** Bucket misconfigurations (public read), old versioned objects with secrets, overpermissive access policies.

### 3. Networking
Things that connect resources:
- **Virtual networks:** VPC, VNet, VPC
- **Firewalls:** Security groups, NSGs, firewall rules
- **Load balancers, DNS, VPN/private links**

**Pentesting:** Misconfigured firewall rules (0.0.0.0/0 on ports 22/3389), hybrid links exposing on-prem resources.

### 4. Identity & Access Control (IAM)
Things that control access:
- **Users, roles, service accounts**
- **Policies (what you can do)**
- **Temporary credentials**

**Pentesting:** Over-privileged roles, service accounts with admin access, lack of privilege boundaries.

### 5. Secrets Management
Things that hold credentials:
- **API keys, passwords, certificates**
- **Secrets managers (AWS Secrets Manager, Azure Key Vault, GCP Secret Manager)**

**Pentesting:** Hardcoded secrets, exposed API keys, overpermissive access to secret stores.

---

## Regions & Availability Zones

### Regions
Geographic locations where resources live:
- us-east-1, us-west-2 (AWS)
- eastus, westus (Azure)
- us-central1, europe-west1 (GCP)

**Affects:** Latency, compliance (data residency), cost

### Availability Zones
Isolated data centers within a region:
- Deploy across zones for redundancy
- Cross-zone traffic costs money

**Pentesting:** Regions may have different compliance rules or risk postures.

---

## Credential Types

### Long-term Credentials
- Access keys / API keys (AWS, GCP)
- Service account keys
- **Never expire** unless rotated manually
- **Risk:** Leaked in code, configs, env vars

### Temporary Credentials
- Assumed role credentials (AWS, GCP)
- Managed identities (Azure)
- **Expire automatically** (hours to days)
- **Risk:** Over-permissioned roles, too-broad assumption policies

**Pentesting:** Temporary credentials are safer, but if the role is admin, it doesn't matter.

---

## Instance Metadata Service (IMDS)

Every cloud instance has access to a local metadata endpoint:

```
AWS: http://169.254.169.254/latest/meta-data/
Azure: http://169.254.169.254/metadata/instance (requires Metadata:true header)
GCP: http://metadata.google.internal/computeMetadata/v1/
```

The endpoint returns:
- Instance identity & credentials
- Configuration
- SSH keys
- Networking details

**Critical:** SSRF → IMDS is a common chain. Weak SSRF validation lets attacker fetch live credentials.

---

## Cloud vs Traditional Pentesting

| Traditional | Cloud |
|---|---|
| Scan for open ports (nmap) | Enumerate IAM permissions (aws iam) |
| Exploit software CVEs | Exploit misconfigurations |
| Pivot through network | Pivot through IAM roles |
| Escalate OS privileges | Escalate cloud permissions |
| Dump password hashes | Steal temporary credentials |
| Persist via cron/registry | Persist via new IAM users/roles |

**The cloud attack surface is configuration, not CVEs.**

---

## Common Cloud Misconfigurations

- Public S3 buckets
- Overpermissive security groups (0.0.0.0/0)
- Service accounts with admin roles
- Versioned S3 objects with exposed secrets
- No IMDSv2 enforcement (vulnerable to SSRF)
- Cross-account trust abuse
- Unencrypted databases
- No MFA on admin accounts

---

## Detection & Evasion

### What Gets Logged
- CloudTrail (AWS), Activity Log (Azure), Cloud Audit Logs (GCP)
- IAM permission checks
- Resource access
- Configuration changes
- Credential usage

### Evasion
- Enumerate during off-hours
- Use legitimate tools
- Leverage assumed roles (looks more legit than direct API calls)
- Clean up logs if possible

---

## Related Guides
- [[Cloud Metadata Service Attacks]] — SSRF → IMDS exploitation
- [[Cloud IAM & Identity]] — understanding cloud access control
- [[Cloud Privilege Escalation]] — escalating within cloud
- [[Cloud Lateral Movement]] — moving between services and accounts
- [[Hybrid Networking Attacks]] — on-prem ↔ cloud pivoting
