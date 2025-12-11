# ArgoCD Troubleshooting Guide

## Common ArgoCD Issues and Solutions

### 1. Application Sync Issues

#### Application Stuck in "Syncing"
```bash
# Check application status
argocd app get <app-name>

# Get detailed sync status
argocd app get <app-name> --refresh

# Force sync termination
argocd app terminate-op <app-name>

# Retry sync
argocd app sync <app-name> --retry-limit 3
```

#### OutOfSync but Nothing to Sync
```bash
# Common causes: Drift detection, ignored differences

# Hard refresh to recalculate diff
argocd app diff <app-name> --hard-refresh

# Check for ignored differences in Application spec
kubectl get application <app-name> -n argocd -o jsonpath='{.spec.ignoreDifferences}'

# Force sync with replace
argocd app sync <app-name> --force --replace
```

### 2. Repository Connection Issues

#### Repository Not Accessible
```bash
# List repositories
argocd repo list

# Test repository connection
argocd repo get <repo-url>

# Re-add repository with credentials
argocd repo add <repo-url> \
  --username <username> \
  --password <password> \
  --insecure-skip-server-verification

# For SSH
argocd repo add git@github.com:org/repo.git \
  --ssh-private-key-path ~/.ssh/id_rsa
```

#### Fix Repository Secret
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: repo-secret
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: https://github.com/org/repo
  password: <token>
  username: not-used
```

### 3. Sync Hooks Issues

#### PreSync/PostSync Hook Failures
```bash
# List sync hooks
kubectl get jobs -n <namespace> -l argocd.argoproj.io/hook

# Check hook status
kubectl describe job <hook-job> -n <namespace>

# Delete failed hooks
kubectl delete job -n <namespace> -l argocd.argoproj.io/hook

# Skip hooks during sync
argocd app sync <app-name> --skip-hooks
```

### 4. Resource Management

#### Pruning Issues
```bash
# Enable auto-prune
argocd app set <app-name> --auto-prune

# Manual prune
argocd app sync <app-name> --prune

# Selective pruning
kubectl patch application <app-name> -n argocd --type='json' \
  -p='[{"op": "add", "path": "/spec/syncPolicy/syncOptions", "value": ["PrunePropagationPolicy=foreground"]}]'
```

#### Resource Limits
```yaml
# Fix: Configure resource tracking
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
    - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### 5. RBAC Issues

#### Check RBAC Policies
```bash
# List RBAC policies
argocd rbac get-policy

# Check user permissions
argocd rbac can <user> get applications <app-name>

# Update RBAC ConfigMap
kubectl edit configmap argocd-rbac-cm -n argocd
```

### 6. Performance Issues

#### Slow Sync Operations
```bash
# Check controller metrics
kubectl port-forward -n argocd svc/argocd-metrics 8082:8082
curl localhost:8082/metrics | grep argocd_app_

# Increase sync parallelism
kubectl patch configmap argocd-cm -n argocd \
  --type merge -p '{"data":{"application.instanceLabelKey":"argocd.argoproj.io/instance","controller.operation.processors":"50","controller.status.processors":"20"}}'

# Restart controller
kubectl rollout restart deployment argocd-application-controller -n argocd
```

## ArgoCD Debugging Commands

### Essential Commands
```bash
# Get application details
argocd app get <app-name> -o yaml

# Watch application sync
argocd app wait <app-name> --sync

# Get application manifests
argocd app manifests <app-name>

# Compare desired vs live state
argocd app diff <app-name>

# Get sync windows
argocd app windows list <app-name>
```

### Log Analysis
```bash
# Application controller logs
kubectl logs -n argocd deployment/argocd-application-controller -f

# Repo server logs
kubectl logs -n argocd deployment/argocd-repo-server -f

# Server logs
kubectl logs -n argocd deployment/argocd-server -f

# Dex logs (for SSO issues)
kubectl logs -n argocd deployment/argocd-dex-server -f
```

## Common Manifest Templates

### Application with Auto-sync
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/org/repo
    targetRevision: main
    path: k8s/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### AppProject with Restrictions
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
  namespace: argocd
spec:
  description: Production applications
  sourceRepos:
  - 'https://github.com/org/*'
  destinations:
  - namespace: 'prod-*'
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: ''
    kind: Namespace
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
  roles:
  - name: admin
    policies:
    - p, proj:production:admin, applications, *, production/*, allow
    groups:
    - org:team-admin
```

### Repository Secret with Helm
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: helm-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: helm
  url: https://charts.example.com
  name: example-charts
  username: <username>
  password: <password>
```

## Sync Strategies

### Progressive Sync
```yaml
# Use sync waves for ordered deployment
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"  # Deploy first
---
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "2"  # Deploy second
```

### Sync Options
```yaml
spec:
  syncPolicy:
    syncOptions:
    - ApplyOutOfSyncOnly=true  # Only sync out-of-sync resources
    - CreateNamespace=true      # Create namespace if missing
    - PruneLast=true           # Delete resources after others are synced
    - Replace=true             # Use kubectl replace instead of apply
    - ServerSideApply=true     # Use server-side apply
```

## Troubleshooting Workflow

1. **Check Application Status**: `argocd app get <app>`
2. **Review Events**: `kubectl describe application <app> -n argocd`
3. **Check Sync Diff**: `argocd app diff <app>`
4. **Verify Repository Access**: `argocd repo get <repo-url>`
5. **Examine Controller Logs**: `kubectl logs -n argocd deployment/argocd-application-controller`
6. **Test Manual Sync**: `argocd app sync <app> --dry-run`
7. **Check Resource Health**: `argocd app resources <app>`
8. **Verify RBAC**: `argocd rbac can <user> sync applications <app>`
