# Diagnose-K8sPod.ps1 - Comprehensive pod troubleshooting for PowerShell

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Namespace,

    [Parameter(Mandatory=$true, Position=1)]
    [string]$PodName
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Pod Diagnosis: $PodName" -ForegroundColor Cyan
Write-Host "  Namespace: $Namespace" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check if pod exists
$podExists = kubectl get pod $PodName -n $Namespace 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Pod not found: $PodName in namespace $Namespace" -ForegroundColor Red
    Write-Host ""
    Write-Host "Available pods in namespace:"
    kubectl get pods -n $Namespace
    exit 1
}

# Basic pod information
Write-Host "📊 Pod Status:" -ForegroundColor Yellow
kubectl get pod $PodName -n $Namespace -o wide
Write-Host ""

# Detailed pod description
Write-Host "📋 Pod Description:" -ForegroundColor Yellow
kubectl describe pod $PodName -n $Namespace | Select-Object -First 50
Write-Host ""

# Container statuses
Write-Host "📦 Container Status:" -ForegroundColor Yellow
$podJson = kubectl get pod $PodName -n $Namespace -o json | ConvertFrom-Json
foreach ($container in $podJson.status.containerStatuses) {
    Write-Host "Container: $($container.name)"
    Write-Host "Ready: $($container.ready)"
    Write-Host "Restart Count: $($container.restartCount)"
    $state = $container.state.PSObject.Properties.Name | Select-Object -First 1
    Write-Host "State: $state"
    Write-Host ""
}

# Recent events
Write-Host "📅 Recent Events:" -ForegroundColor Yellow
kubectl get events -n $Namespace --field-selector involvedObject.name=$PodName --sort-by='.lastTimestamp' | Select-Object -Last 10
Write-Host ""

# Resource usage
Write-Host "💾 Resource Usage:" -ForegroundColor Yellow
$metrics = kubectl top pod $PodName -n $Namespace 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host $metrics
} else {
    Write-Host "Metrics not available"
}
Write-Host ""

# Check logs
Write-Host "📜 Recent Logs (last 20 lines):" -ForegroundColor Yellow
$logs = kubectl logs $PodName -n $Namespace --tail=20 --all-containers=true 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host $logs
} else {
    Write-Host "No logs available or pod hasn't started"
}
Write-Host ""

# Common issues check
Write-Host "🔍 Common Issues Analysis:" -ForegroundColor Yellow

$description = kubectl describe pod $PodName -n $Namespace

# Check for image pull errors
if ($description -match "ErrImagePull|ImagePullBackOff") {
    Write-Host "⚠️  Image Pull Issue Detected!" -ForegroundColor Red
    Write-Host "   Check: - Image name and tag"
    Write-Host "         - Image pull secrets"
    Write-Host "         - Registry accessibility"
}

# Check for crash loops
if ($description -match "CrashLoopBackOff") {
    Write-Host "⚠️  CrashLoopBackOff Detected!" -ForegroundColor Red
    Write-Host "   Check: - Application logs"
    Write-Host "         - Liveness/Readiness probes"
    Write-Host "         - Resource limits"
}

# Check for pending state
$podPhase = $podJson.status.phase
if ($podPhase -eq "Pending") {
    Write-Host "⚠️  Pod is Pending!" -ForegroundColor Red
    Write-Host "   Possible causes:"
    Write-Host "   - Insufficient resources"
    Write-Host "   - PVC not bound"
    Write-Host "   - Node selector/affinity issues"
    
    # Check for unschedulable conditions
    foreach ($condition in $podJson.status.conditions) {
        if ($condition.type -eq "PodScheduled" -and $condition.status -eq "False") {
            Write-Host "   Reason: $($condition.reason)"
            Write-Host "   Message: $($condition.message)"
        }
    }
}

# Check for resource requests
$requests = @()
foreach ($container in $podJson.spec.containers) {
    if ($container.resources.requests) {
        foreach ($key in $container.resources.requests.PSObject.Properties.Name) {
            $requests += "$key=$($container.resources.requests.$key)"
        }
    }
}
if ($requests.Count -gt 0) {
    Write-Host ""
    Write-Host "📊 Resource Requests: $($requests -join ', ')"
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Suggested Actions" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Provide contextual suggestions
if ($description -match "Back-off pulling image") {
    Write-Host "1. Fix image pull issue:"
    Write-Host "   kubectl set image pod/$PodName <container>=<correct-image> -n $Namespace"
}

if ($podPhase -eq "Pending") {
    Write-Host "2. Check node resources:"
    Write-Host "   kubectl top nodes"
    Write-Host "   kubectl describe nodes"
}

Write-Host ""
Write-Host "For more detailed debugging:"
Write-Host "- Shell into pod: kubectl exec -it $PodName -n $Namespace -- /bin/bash"
Write-Host "- Get full logs: kubectl logs $PodName -n $Namespace --all-containers=true"
Write-Host "- Watch events: kubectl get events -n $Namespace -w"
