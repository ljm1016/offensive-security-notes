#enumeration #active-directory #graph-analysis

Bloodhound visualizes Active Directory as a graph, revealing attack paths and privilege escalation routes. Enables two-stage attacks: offline analysis followed by targeted compromise.

---

## Bloodhound Philosophy

### Graph-based thinking
**Traditional approach:** "Defenders think in lists" (Domain Admins list, users list, etc.)

**Bloodhound approach:** "Attackers think in graphs" (interconnected nodes showing exploitation paths)

**Power:** Shows not just what exists, but HOW to compromise it through chains of permissions.

### Attack workflow
1. **Stage 1:** Run Sharphound to enumerate AD (noisy, may be detected)
2. **Offline analysis:** Use Bloodhound to plan attack path without generating more noise
3. **Stage 2:** Execute targeted attack following the planned path (faster, harder to detect)

---

## Sharphound Collection

### Sharphound types
- **Sharphound.exe** — Windows executable (detectable by AV)
- **Sharphound.ps1** — PowerShell script (can be loaded in memory)
- **AzureHound.ps1** — For Azure/Office 365 enumeration

### Collection methods
```powershell
# Default: Basic AD structure (users, groups, computers)
SharpHound.exe --CollectionMethods Default --Domain domain.com

# All: Everything (includes sessions, logons, ACLs, GPOs)
SharpHound.exe --CollectionMethods All --Domain domain.com

# Session only: Active user sessions (fast, for repeat runs)
SharpHound.exe --CollectionMethods Session --Domain domain.com
```

### Running Sharphound
```powershell
# From non-domain-joined machine with injected creds
runas.exe /netonly /user:domain.com\username powershell.exe

# Then run
SharpHound.exe --CollectionMethods All --Domain domain.com --ExcludeDCs
```

**Output:** ZIP file containing JSON files for import into Bloodhound

---

## Bloodhound Setup

### Install Neo4j (graph database)
```bash
# Linux/MacOS
neo4j console start

# Output shows: Bolt listening on 127.0.0.1:7687
```

### Launch Bloodhound
```bash
# Second terminal
bloodhound --no-sandbox
```

**Login:** Default credentials are `neo4j:neo4j` (change after first login)

### Import Sharphound data
1. Drag-and-drop ZIP file onto Bloodhound GUI
2. Wait for JSON files to import
3. Check "Database Info" tab for import statistics

---

## Node Information Analysis

### Searching for nodes
Search for users, computers, or groups by name in the search box. Click on node to view details.

### Node detail tabs

#### Overview
- Current number of active sessions
- Whether account can reach high-value targets
- Account status (enabled/disabled)
- Account type (user, computer, group)

#### Node Properties
- Display name
- Account created date
- Last logon date
- Password last set
- Account enabled status
- Description/comments

#### Group Membership
- Direct groups (member of)
- Nested groups (groups in groups)
- Count of group memberships

#### Local Admin Rights
- Which domain-joined machines this user has admin rights on
- Useful for identifying privilege escalation targets

#### Execution Rights
- RDP access to machines
- WinRM access
- DCOM execution rights

#### Outbound Control Rights
- AD objects this account can modify
- Useful for finding privilege escalation paths

#### Inbound Control Rights
- Which accounts can modify this account
- Can indicate security group memberships with dangerous permissions

---

## Analysis Queries

### Domain Information section
**Find all Domain Admins**
```
Bloodhound menu → Analysis → Domain Information → Find all Domain Admins
```
Shows graph of:
- Domain Admins group
- All users/accounts that are domain admins
- Nested group relationships

**Find all High Value Targets**
```
Shows: Domain admins, enterprise admins, schema admins, backup operators
```

**Find user/computer properties**
```
Shows: When accounts were created, last logon, password last set
Useful for finding stale accounts or recently created backdoors
```

### Exploitation paths section
**Shortest Path to Domain Admin**
```
Select your current user as start node
Select Domain Admins as end node
Bloodhound finds shortest exploitation path
```

Shows each hop required (edges) and what attack exploits each edge.

### User Analysis
**Find privileges for a specific user**
```
Search user → Overview tab
Shows what systems user can access, groups, admin rights
```

**Find users that can RDP to a machine**
```
Search machine → Overview → Inbound RDP Rights
Shows which users can RDP into that machine
```

---

## Understanding Edges (Attack Paths)

### Common edges
- **MemberOf** — User is member of group
- **AdminTo** — User has admin rights on computer
- **CanRDP** — User can RDP to computer
- **CanPSRemote** — User can PowerShell remote to computer
- **ExecuteDCOM** — User can execute DCOM on computer
- **ForceChangePassword** — User can force password change on another user
- **GenericAll** — User has full control over object
- **GenericWrite** — User can write to object attributes
- **WriteDacl** — User can modify object permissions
- **WriteOwner** — User can change object owner
- **AddMember** — User can add members to group

### ACL edges
Permissions on AD objects that grant control:
- Can reset passwords
- Can modify group membership
- Can modify object properties
- Can take ownership

---

## Attack Path Analysis

### Example scenario
```
Current position: Regular user account (you compromised)
Goal: Domain Admin

Bloodhound path:
1. User is member of → "IT Staff" group
2. "IT Staff" group has GenericAll on → Workstation1
3. Workstation1 has local admin → DomainAdmin account (T1_Admin)
4. T1_Admin is member of → "Tier 1 Admins"
5. "Tier 1 Admins" is member of → "Domain Admins"
```

**Exploitation:**
1. Use current user to access Workstation1 (as IT Staff group member)
2. Dump credentials from Workstation1 (T1_Admin cached credentials)
3. Use T1_Admin account to gain Domain Admin access

---

## Advanced Features

### Path finding
```
Click path icon at top → Select start and end nodes
Bloodhound calculates shortest path using selected edges
```

### Edge filtering
```
Click filter icon → Toggle which edges to consider
Useful for: Hiding weak edges, focusing on ACL paths, etc.
```

### Session data refresh
```
Run Sharphound with "Session" method every 8 hours
Sessions change as users log in/out
Database Info → Clear Session Information before import
```

### Custom queries
```
Advanced tab → Write custom Cypher queries
Cypher = graph query language (similar to SQL for graphs)
```

---

## Workflow: Full Bloodhound Analysis

### Step 1: Collect AD data
```powershell
# Use Runas if not domain-joined
runas.exe /netonly /user:domain.com\user powershell.exe

# Run Sharphound
SharpHound.exe --CollectionMethods All --Domain domain.com
```

### Step 2: Transfer results to attack machine
```bash
# Copy ZIP to attack machine
scp user@target:path/to/bloodhound.zip .
```

### Step 3: Import into Bloodhound
```
1. Start Neo4j (neo4j console start)
2. Launch Bloodhound (bloodhound --no-sandbox)
3. Drag-drop ZIP onto GUI
4. Wait for import to complete
```

### Step 4: Analyze current position
```
Search your compromised user account
Review Overview tab:
- Group memberships
- Admin rights
- RDP/execution capabilities
```

### Step 5: Find attack path
```
Use Analysis → Shortest Path to Domain Admin
Or: Use path finder to specific target (domain admins, server, etc.)
```

### Step 6: Plan exploitation
```
For each edge in path:
1. Understand what attack exploits that edge
2. Verify it's possible with current access
3. Plan execution sequence
```

### Step 7: Execute
```
Follow the path:
1. Move to next node in path
2. Compromise that system
3. Extract credentials if needed
4. Continue to next hop
```

---

## Key Insights from Bloodhound

### Tier violations
If high-privilege accounts (Tier 1/2 Admins) access low-privilege workstations, it creates compromise path:
- Compromise workstation (easier)
- Dump admin creds from workstation (Mimikatz)
- Use admin creds for privilege escalation

### Dangerous permissions
- **GenericAll** — Full control (very dangerous)
- **ForceChangePassword** — Can reset any account's password
- **WriteDacl** — Can modify permissions on object
- **WriteOwner** — Can become owner of object

### Group nesting
Nested groups compound privilege:
- User in Group A
- Group A in Group B
- Group B has admin rights
- Result: User is effective admin (through inheritance)

### Session-based paths
Sessions are time-dependent (users log in/out). Best times to target:
- Morning (10:00) — Users starting work
- Afternoon (14:00) — Users returning from lunch
- Run Sharphound at these times for fresh session data

---

## Detection & Evasion

### Sharphound detection
- Large executable/script running
- Multiple LDAP queries
- Accessing all domain objects
- Often flagged by AV/EDR

**Evasion:**
- Disable AV (if admin)
- Add Sharphound to AV exclusions
- Run on off-hours
- Use PowerShell version (in-memory)
- Use "Session" method for repeat runs (faster, less noisy)

### Bloodhound doesn't generate network traffic
- Offline analysis (no alerts)
- Run on isolated attack machine
- Plan attack without triggering IDS

---

## Version compatibility

**Important:** Bloodhound and Sharphound versions must match
- Sharphound v4.1.0 → Bloodhound v4.1.0
- Version mismatch = import failures or incomplete data

Check version in Bloodhound GUI and match Sharphound download.

---

## Benefits

- Visualizes complex AD relationships
- Identifies privilege escalation paths
- Shows what's exploitable vs. what's theoretical
- Offline analysis (stealthy)
- Reveals weak link in chain (focus point)
- Graph-based thinking reveals non-obvious paths

---

## Drawbacks

- Sharphound collection is noisy (may be detected)
- Requires data export from target
- Point-in-time snapshot (sessions change)
- Neo4j requires setup on attack machine
- Learning curve (understanding Cypher, edges, etc.)

---

**See also:**
- [[AD Enumeration with Runas]] — running Sharphound with injected creds
- [[PowerShell AD Enumeration]] — manual AD data collection
- [[NTLM Password Spraying]] — finding initial valid credentials
- [[Windows Privilege Escalation]] — exploiting attack paths found by Bloodhound
