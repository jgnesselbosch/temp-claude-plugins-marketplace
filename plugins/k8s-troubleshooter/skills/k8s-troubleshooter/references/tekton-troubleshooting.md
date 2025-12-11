# Tekton Troubleshooting Guide

## Common Tekton Issues and Solutions

### Pipeline Run Failures

#### 1. PipelineRun Stuck in Pending
```bash
# Check PipelineRun status
tkn pipelinerun describe <pr-name> -n <namespace>

# Check for missing PVCs
kubectl get pvc -n <namespace> | grep tekton

# Common fix: Create workspace PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: tekton-workspace-pvc
  namespace: <namespace>
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
```

#### 2. Task Failures
```bash
# Get TaskRun logs
tkn taskrun logs <tr-name> -n <namespace>

# List all TaskRuns for a PipelineRun
tkn taskrun list -n <namespace> | grep <pr-name>

# Debug specific step
kubectl logs -n <namespace> <taskrun-pod> -c step-<step-name>
```

#### 3. Authentication Issues
```bash
# Check service account
kubectl get serviceaccount -n <namespace> | grep tekton
kubectl describe serviceaccount <sa-name> -n <namespace>

# Fix: Add git credentials
kubectl create secret generic git-credentials \
  --from-literal=username=<username> \
  --from-literal=password=<token> \
  -n <namespace>

# Link to service account
kubectl patch serviceaccount tekton-sa -n <namespace> \
  -p '{"secrets": [{"name": "git-credentials"}]}'
```

### Tekton Trigger Issues

#### 1. EventListener Not Receiving Events
```bash
# Check EventListener
kubectl get eventlistener -n <namespace>
kubectl describe eventlistener <el-name> -n <namespace>

# Check if service is exposed
kubectl get svc -n <namespace> | grep el-

# Test webhook
curl -X POST http://<el-service>:8080 \
  -H "Content-Type: application/json" \
  -d '{"test": "payload"}'
```

#### 2. TriggerBinding Issues
```bash
# Validate TriggerBinding
kubectl describe triggerbinding <tb-name> -n <namespace>

# Check parameter extraction
tkn triggerbinding describe <tb-name> -n <namespace>
```

### Resource Management

#### Clean up old PipelineRuns
```bash
# Delete PipelineRuns older than 7 days
tkn pipelinerun delete --keep 10 -n <namespace>

# Or use kubectl
kubectl delete pipelinerun -n <namespace> \
  $(kubectl get pipelinerun -n <namespace> -o name | head -20)
```

### Debugging Commands Cheat Sheet

```bash
# List all Tekton CRDs
kubectl get crds | grep tekton

# Get all Tekton resources in namespace
kubectl get tekton-pipelines.tekton.dev -n <namespace>

# Watch PipelineRun progress
tkn pipelinerun logs <pr-name> -n <namespace> -f

# Get PipelineRun YAML for debugging
tkn pipelinerun describe <pr-name> -n <namespace> -o yaml

# Check Tekton operator status
kubectl get deployment -n tekton-pipelines
```

## Tekton Performance Tuning

### Parallel Task Execution
```yaml
# Increase parallelism in Pipeline
spec:
  tasks:
    - name: task1
      taskRef:
        name: build
    - name: task2
      taskRef:
        name: test
      runAfter: []  # Run in parallel with task1
```

### Resource Optimization
```yaml
# Set appropriate resource limits
spec:
  taskRunSpec:
    podTemplate:
      resources:
        limits:
          cpu: "2"
          memory: "2Gi"
        requests:
          cpu: "500m"
          memory: "512Mi"
```

## Common Manifest Templates

### Basic PipelineRun with Workspace
```yaml
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: manual-pipeline-run
  namespace: <namespace>
spec:
  pipelineRef:
    name: <pipeline-name>
  workspaces:
    - name: shared-workspace
      persistentVolumeClaim:
        claimName: tekton-workspace-pvc
  params:
    - name: repo-url
      value: "https://github.com/example/repo"
    - name: revision
      value: "main"
```

### Service Account with Secrets
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tekton-sa
  namespace: <namespace>
secrets:
  - name: git-credentials
  - name: docker-credentials
imagePullSecrets:
  - name: registry-credentials
```
