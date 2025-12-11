# AI Agent Guide: Creating Fixed Kubernetes Manifests

## Purpose
This guide helps AI agents (like Claude Code) properly create fixed Kubernetes manifest files during troubleshooting sessions.

## Workflow

### Step 1: Backup Current Resource
Always backup the current state before making changes:

**Bash:**
```bash
kubectl get <resource-type> <name> -n <namespace> -o yaml > "$SESSION_DIR/backup-<resource>-<name>.yaml"
```

**PowerShell:**
```powershell
kubectl get <resource-type> <name> -n <namespace> -o yaml | Out-File "$env:K8S_SESSION_DIR\backup-<resource>-<name>.yaml" -Encoding utf8
```

### Step 2: Read and Analyze
Read the backup YAML to understand the current configuration and identify what needs to be fixed.

### Step 3: Create Fixed Manifest

**Critical: Clean the YAML by removing these fields:**

```yaml
# ALWAYS REMOVE these metadata fields:
metadata:
  resourceVersion: "..."        # REMOVE
  uid: "..."                    # REMOVE
  selfLink: "..."               # REMOVE
  creationTimestamp: "..."      # REMOVE
  generation: 1                 # REMOVE
  managedFields: [...]          # REMOVE entire array

# ALWAYS REMOVE this entire section:
status: { ... }                 # REMOVE entire status section
```

**Keep these metadata fields:**
```yaml
metadata:
  name: "..."                   # KEEP
  namespace: "..."              # KEEP
  labels: { ... }               # KEEP
  annotations: { ... }          # KEEP (but clean up kubectl/system annotations if needed)
```

### Step 4: Apply Your Fixes

Make the actual changes needed, such as:
- Update image tags
- Adjust resource limits/requests
- Fix environment variables
- Correct volume mounts
- Update replica counts
- Fix service selectors

### Step 5: Write Fixed Manifest

**Bash:**
```bash
# Write to: $SESSION_DIR/fixed-<resource-type>-<name>.yaml
```

**PowerShell:**
```powershell
# Write to: $env:K8S_SESSION_DIR\fixed-<resource-type>-<name>.yaml
```

### Step 6: Apply with Tracking

**Bash:**
```bash
scripts/apply_with_tracking.sh "$SESSION_DIR/fixed-<resource-type>-<name>.yaml"
```

**PowerShell:**
```powershell
.\scripts\ps1\Apply-K8sWithTracking.ps1 -ManifestFile "$env:K8S_SESSION_DIR\fixed-<resource-type>-<name>.yaml"
```

## Complete Example: Fixing Deployment Image

### Scenario
A deployment `web-app` in namespace `production` has wrong image tag `myapp:broken`.

### AI Agent Steps

```bash
# 1. Backup current deployment
kubectl get deployment web-app -n production -o yaml > "$SESSION_DIR/backup-deployment-web-app.yaml"

# 2. AI reads the backup and identifies:
#    - Current image: myregistry.com/myapp:broken
#    - Fix needed: Change to myregistry.com/myapp:v1.2.3

# 3. AI creates fixed manifest using Write tool
# Path: $SESSION_DIR/fixed-deployment-web-app.yaml
# Content:
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: production
  labels:
    app: web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web-app
        image: myregistry.com/myapp:v1.2.3  # FIXED: was 'broken'
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

```bash
# 4. Apply with tracking
scripts/apply_with_tracking.sh "$SESSION_DIR/fixed-deployment-web-app.yaml"
```

## Common Fixes and Patterns

### Image Tag Fix
```yaml
# Before
image: myapp:latest
# After
image: myapp:v1.2.3
```

### Resource Limits
```yaml
# Before
resources: {}
# After
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

### Environment Variable Fix
```yaml
# Before
env:
- name: DATABASE_URL
  value: "wrong-url"
# After
env:
- name: DATABASE_URL
  value: "postgres://correct-host:5432/mydb"
```

### Add Missing Image Pull Secret
```yaml
# Before
spec:
  containers: [...]
# After
spec:
  imagePullSecrets:
  - name: registry-credentials
  containers: [...]
```

## Important Notes for AI Agents

1. **Always use Write tool** to create the fixed manifest in the session temp directory
2. **Never create files** in the current working directory (git repo)
3. **Always clean metadata** before writing fixed manifest
4. **Preserve labels and annotations** that are application-specific
5. **Remove kubectl-specific annotations** like `kubectl.kubernetes.io/last-applied-configuration`
6. **Test the fix** by verifying the resource after applying
7. **Document the change** - the tracking script will automatically record it

## Validation Checklist

Before applying the fixed manifest, verify:
- [ ] File is in session temp directory (not working directory)
- [ ] Removed: resourceVersion, uid, selfLink, creationTimestamp, generation, managedFields
- [ ] Removed: entire `status` section
- [ ] Kept: name, namespace, labels, annotations (user-defined)
- [ ] Applied the actual fix (image, resources, config, etc.)
- [ ] YAML is valid syntax
- [ ] Required fields for the resource type are present

## Error Prevention

**Common mistakes to avoid:**
- ❌ Writing fixed manifest to current working directory
- ❌ Keeping `resourceVersion` field (causes apply conflicts)
- ❌ Keeping `status` section (will be ignored/cause issues)
- ❌ Not backing up before applying changes
- ❌ Using imperative commands instead of declarative manifests
- ❌ Forgetting to track the change

**Correct approach:**
- ✅ Write to `$SESSION_DIR/fixed-*.yaml` or `$env:K8S_SESSION_DIR\fixed-*.yaml`
- ✅ Clean all cluster-generated metadata
- ✅ Create proper declarative YAML
- ✅ Use apply_with_tracking script
- ✅ Verify resource state after applying
