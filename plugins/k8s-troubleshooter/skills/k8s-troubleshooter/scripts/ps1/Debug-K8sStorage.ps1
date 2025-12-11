# Debug-K8sStorage.ps1 - Debug Kubernetes storage issues (PVCs, PVs, StorageClasses)

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Namespace
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Storage Debugging" -ForegroundColor Cyan
Write-Host "  Namespace: $Namespace" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check PVCs in namespace
Write-Host "📦 Persistent Volume Claims (PVCs):" -ForegroundColor Yellow
$pvcList = kubectl get pvc -n $Namespace --no-headers 2>$null
$pvcCount = if ($pvcList) { ($pvcList | Measure-Object).Count } else { 0 }

if ($pvcCount -eq 0) {
    Write-Host "ℹ️  No PVCs found in namespace $Namespace" -ForegroundColor Blue
} else {
    kubectl get pvc -n $Namespace
    Write-Host ""
    
    # Check each PVC status
    Write-Host "🔍 PVC Status Analysis:" -ForegroundColor Yellow
    $pvcJson = kubectl get pvc -n $Namespace -o json | ConvertFrom-Json
    
    foreach ($pvc in $pvcJson.items) {
        $pvcName = $pvc.metadata.name
        $status = $pvc.status.phase
        
        if ($status -ne "Bound") {
            Write-Host "⚠️  PVC $pvcName is $status" -ForegroundColor Yellow
            Write-Host "   Details:"
            kubectl describe pvc $pvcName -n $Namespace | Select-String -Pattern "Events:" -Context 0,5
        } else {
            Write-Host "✅ PVC $pvcName is Bound" -ForegroundColor Green
        }
    }
}
Write-Host ""

# Check Persistent Volumes (cluster-wide)
Write-Host "💾 Persistent Volumes (PVs):" -ForegroundColor Yellow
kubectl get pv
Write-Host ""

# Check Storage Classes
Write-Host "🗂️  Storage Classes:" -ForegroundColor Yellow
kubectl get storageclass
Write-Host ""

# Detailed analysis of each PVC
if ($pvcCount -gt 0) {
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "  Detailed PVC Analysis" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $pvcJson = kubectl get pvc -n $Namespace -o json | ConvertFrom-Json
    
    foreach ($pvc in $pvcJson.items) {
        $pvcName = $pvc.metadata.name
        
        Write-Host "📋 PVC: $pvcName" -ForegroundColor Yellow
        Write-Host "---"
        
        $status = $pvc.status.phase
        $storageClass = if ($pvc.spec.storageClassName) { $pvc.spec.storageClassName } else { "default" }
        $requestedSize = $pvc.spec.resources.requests.storage
        $accessModes = $pvc.spec.accessModes -join ", "
        $volumeName = if ($pvc.spec.volumeName) { $pvc.spec.volumeName } else { "unbound" }
        
        Write-Host "Status: $status"
        Write-Host "Storage Class: $storageClass"
        Write-Host "Requested Size: $requestedSize"
        Write-Host "Access Modes: $accessModes"
        Write-Host "Bound to PV: $volumeName"
        
        # Check if bound to a PV
        if ($volumeName -ne "unbound" -and $null -ne $volumeName) {
            Write-Host ""
            Write-Host "PV Details:"
            $pvJson = kubectl get pv $volumeName -o json | ConvertFrom-Json
            Write-Host "  Capacity: $($pvJson.spec.capacity.storage)"
            Write-Host "  Reclaim Policy: $($pvJson.spec.persistentVolumeReclaimPolicy)"
            Write-Host "  Status: $($pvJson.status.phase)"
        }
        
        # Check which pods use this PVC
        Write-Host ""
        Write-Host "Pods using this PVC:"
        $allPodsJson = kubectl get pods -n $Namespace -o json | ConvertFrom-Json
        $podsUsingPvc = @()
        
        foreach ($pod in $allPodsJson.items) {
            foreach ($volume in $pod.spec.volumes) {
                if ($volume.persistentVolumeClaim.claimName -eq $pvcName) {
                    $podsUsingPvc += $pod.metadata.name
                }
            }
        }
        
        if ($podsUsingPvc.Count -eq 0) {
            Write-Host "  No pods currently using this PVC"
        } else {
            foreach ($pod in $podsUsingPvc) {
                Write-Host "  - $pod"
            }
        }
        
        Write-Host ""
        Write-Host "---"
        Write-Host ""
    }
}

# Check for common storage issues
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Common Issues Check" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check for pending PVCs
$pvcJson = kubectl get pvc -n $Namespace -o json 2>$null | ConvertFrom-Json
$pendingPvcs = @()
if ($pvcJson.items) {
    $pendingPvcs = $pvcJson.items | Where-Object { $_.status.phase -eq "Pending" } | Select-Object -ExpandProperty metadata | Select-Object -ExpandProperty name
}

if ($pendingPvcs.Count -gt 0) {
    Write-Host "⚠️  Pending PVCs detected:" -ForegroundColor Red
    foreach ($pvc in $pendingPvcs) {
        Write-Host "  - $pvc"
        Write-Host "    Possible causes:"
        Write-Host "      • No available PV matching the PVC requirements"
        Write-Host "      • StorageClass provisioner not working"
        Write-Host "      • Insufficient storage quota"
        Write-Host "      • Access mode mismatch"
    }
    Write-Host ""
}

# Check for lost PVs
$pvJson = kubectl get pv -o json 2>$null | ConvertFrom-Json
$lostPvs = @()
if ($pvJson.items) {
    $lostPvs = $pvJson.items | Where-Object { $_.status.phase -eq "Failed" -or $_.status.phase -eq "Released" } | Select-Object -ExpandProperty metadata | Select-Object -ExpandProperty name
}

if ($lostPvs.Count -gt 0) {
    Write-Host "⚠️  PVs in Failed/Released state:" -ForegroundColor Red
    foreach ($pv in $lostPvs) {
        $pvStatus = kubectl get pv $pv -o jsonpath='{.status.phase}'
        Write-Host "  - $pv ($pvStatus)"
    }
    Write-Host ""
}

# Check storage class provisioners
Write-Host "🔧 Storage Class Provisioners:" -ForegroundColor Yellow
$scJson = kubectl get storageclass -o json | ConvertFrom-Json
foreach ($sc in $scJson.items) {
    Write-Host "$($sc.metadata.name): $($sc.provisioner)"
}
Write-Host ""

# Recent storage-related events
Write-Host "📅 Recent Storage Events:" -ForegroundColor Yellow
$events = kubectl get events -n $Namespace --sort-by='.lastTimestamp' 2>$null | Select-String -Pattern "volume|pvc|pv|storage" -CaseSensitive:$false | Select-Object -Last 10
if ($events) {
    $events
} else {
    Write-Host "No recent storage events"
}
Write-Host ""

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Troubleshooting Suggestions" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

if ($pendingPvcs.Count -gt 0) {
    Write-Host "1. For Pending PVCs:"
    Write-Host "   kubectl describe pvc <pvc-name> -n $Namespace"
    Write-Host "   kubectl get events -n $Namespace | Select-String <pvc-name>"
    Write-Host "   kubectl get storageclass"
    Write-Host ""
}

Write-Host "2. Check StorageClass configuration:"
Write-Host "   kubectl describe storageclass <storage-class-name>"
Write-Host ""

Write-Host "3. Check PV availability:"
Write-Host "   kubectl get pv"
Write-Host "   kubectl describe pv <pv-name>"
Write-Host ""

Write-Host "4. Test volume mounting:"
Write-Host "   Create a test pod with PVC and check if it mounts successfully"
Write-Host ""

Write-Host "5. Check CSI driver logs (if applicable):"
Write-Host "   kubectl logs -n kube-system -l app=<csi-driver-name>"
