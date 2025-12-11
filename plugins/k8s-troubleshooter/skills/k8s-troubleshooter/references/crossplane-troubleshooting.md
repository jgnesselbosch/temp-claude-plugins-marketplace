# Crossplane Troubleshooting Guide

## Understanding Crossplane Resources Hierarchy

```
CompositeResourceDefinition (XRD)
    ↓
Composition
    ↓
CompositeResource (XR) / Claim (XRC)
    ↓
Managed Resources (MR)
```

## Common Crossplane Issues

### 1. XR Not Creating Resources

#### Check XR Status
```bash
# List all XRs
kubectl get composite -A

# Describe specific XR
kubectl describe xr <xr-name>

# Check composition selection
kubectl get xr <xr-name> -o jsonpath='{.spec.compositionRef.name}'
```

#### Common Causes & Fixes

**Missing Composition**
```bash
# List available compositions
kubectl get compositions

# Check if composition matches XR
kubectl get composition <comp-name> -o jsonpath='{.spec.compositeTypeRef}'
```

**Provider Not Ready**
```bash
# Check provider status
kubectl get providers
kubectl describe provider <provider-name>

# Check provider config
kubectl get providerconfig -A
kubectl describe providerconfig <config-name>
```

**Fix: Create Provider Config**
```yaml
apiVersion: <provider>.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: provider-creds
      key: credentials
```

### 2. Composition Debugging

#### Check Composition Patches
```bash
# Get composition details
kubectl get composition <name> -o yaml | less

# Validate patch paths
kubectl explain <resource>.spec.<field>
```

#### Common Patch Issues
```yaml
# Fix: Correct patch syntax
patches:
  - type: FromCompositeFieldPath
    fromFieldPath: spec.parameters.size
    toFieldPath: spec.forProvider.instanceClass
    transforms:
      - type: map
        map:
          small: db.t3.micro
          medium: db.t3.small
          large: db.t3.medium
```

### 3. Managed Resource Issues

#### Check MR Status
```bash
# List all managed resources
kubectl get managed -A

# Check specific MR
kubectl describe <mr-kind> <mr-name>

# Get MR conditions
kubectl get <mr-kind> <mr-name> -o jsonpath='{.status.conditions[*]}'
```

#### Sync Failures
```bash
# Check for sync errors
kubectl get <mr-kind> <mr-name> -o jsonpath='{.status.conditions[?(@.type=="Synced")].message}'

# Force reconciliation
kubectl annotate <mr-kind> <mr-name> crossplane.io/external-create-time="$(date -u +%Y-%m-%dT%H:%M:%SZ)" --overwrite
```

### 4. Provider Authentication Issues

#### Azure Provider
```bash
# Create Azure credentials secret
kubectl create secret generic azure-creds \
  -n crossplane-system \
  --from-literal=credentials='{
    "clientId": "<client-id>",
    "clientSecret": "<client-secret>",
    "tenantId": "<tenant-id>",
    "subscriptionId": "<subscription-id>"
  }'
```

#### AWS Provider
```bash
# Create AWS credentials secret
kubectl create secret generic aws-creds \
  -n crossplane-system \
  --from-literal=credentials='[default]
aws_access_key_id = <key-id>
aws_secret_access_key = <secret-key>'
```

## Crossplane Debugging Commands

### Essential Commands
```bash
# Watch all Crossplane resources
kubectl get crossplane -A -w

# Get provider logs
kubectl logs -n crossplane-system deployment/provider-<name>

# Check RBAC
kubectl get clusterroles | grep crossplane
kubectl get clusterrolebindings | grep crossplane

# Trace XR to MR relationship
kubectl get xr <xr-name> -o jsonpath='{.status.resourceRefs[*]}'
```

### Event Analysis
```bash
# Get all Crossplane events
kubectl get events -A | grep -i crossplane

# Watch specific XR events
kubectl get events --field-selector involvedObject.name=<xr-name> -w
```

## Performance Optimization

### Composition Functions
```yaml
# Use composition functions for complex logic
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: complex-app
spec:
  mode: Pipeline
  pipeline:
    - step: patch-and-transform
      functionRef:
        name: function-patch-and-transform
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          - name: database
            base:
              apiVersion: database.example.io/v1alpha1
              kind: Instance
```

### Resource Pruning
```yaml
# Enable automatic cleanup
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xpostgresqlinstances.database.example.io
spec:
  defaultCompositeDeletePolicy: Background
  defaultCompositionUpdatePolicy: Automatic
```

## Common Manifest Templates

### Basic XRD
```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xpostgresqlinstances.database.example.io
spec:
  group: database.example.io
  names:
    kind: XPostgreSQLInstance
    plural: xpostgresqlinstances
  versions:
  - name: v1alpha1
    served: true
    referenceable: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              parameters:
                type: object
                properties:
                  size:
                    type: string
                    enum: ["small", "medium", "large"]
                required:
                  - size
```

### Composition with Multiple Resources
```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: postgresql-azure
spec:
  compositeTypeRef:
    apiVersion: database.example.io/v1alpha1
    kind: XPostgreSQLInstance
  resources:
    - name: resourcegroup
      base:
        apiVersion: azure.upbound.io/v1beta1
        kind: ResourceGroup
      patches:
        - fromFieldPath: spec.parameters.region
          toFieldPath: spec.forProvider.location
    - name: server
      base:
        apiVersion: dbforpostgresql.azure.upbound.io/v1beta1
        kind: Server
      patches:
        - fromFieldPath: spec.parameters.size
          toFieldPath: spec.forProvider.skuName
          transforms:
            - type: map
              map:
                small: B_Gen5_1
                medium: B_Gen5_2
                large: B_Gen5_4
```

## Troubleshooting Workflow

1. **Start with XR/Claim**: Check if it exists and its status
2. **Verify Composition**: Ensure it's selected and valid
3. **Check Managed Resources**: See if they're created and synced
4. **Review Provider**: Confirm it's healthy and authenticated
5. **Examine Events**: Look for error messages
6. **Check Logs**: Provider and Crossplane pod logs
7. **Validate Patches**: Ensure field paths exist
8. **Test Credentials**: Verify provider can access external API
