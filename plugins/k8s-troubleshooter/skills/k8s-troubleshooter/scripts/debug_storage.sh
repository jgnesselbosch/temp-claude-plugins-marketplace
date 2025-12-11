#!/bin/bash
# debug_storage.sh - Debug Kubernetes storage issues (PVCs, PVs, StorageClasses)

set -euo pipefail

NAMESPACE="${1:-default}"

echo "========================================="
echo "  Storage Debugging"
echo "  Namespace: $NAMESPACE"
echo "========================================="
echo ""

# Check PVCs in namespace
echo "📦 Persistent Volume Claims (PVCs):"
PVC_COUNT=$(kubectl get pvc -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)

if [ "$PVC_COUNT" -eq 0 ]; then
    echo "ℹ️  No PVCs found in namespace $NAMESPACE"
else
    kubectl get pvc -n "$NAMESPACE"
    echo ""
    
    # Check each PVC status
    echo "🔍 PVC Status Analysis:"
    kubectl get pvc -n "$NAMESPACE" -o json | jq -r '.items[] | "\(.metadata.name): \(.status.phase)"' | while read -r line; do
        PVC_NAME=$(echo "$line" | cut -d: -f1)
        STATUS=$(echo "$line" | cut -d: -f2 | xargs)
        
        if [ "$STATUS" != "Bound" ]; then
            echo "⚠️  PVC $PVC_NAME is $STATUS"
            echo "   Details:"
            kubectl describe pvc "$PVC_NAME" -n "$NAMESPACE" | grep -A 5 "Events:"
        else
            echo "✅ PVC $PVC_NAME is Bound"
        fi
    done
fi
echo ""

# Check Persistent Volumes (cluster-wide)
echo "💾 Persistent Volumes (PVs):"
kubectl get pv
echo ""

# Check Storage Classes
echo "🗂️  Storage Classes:"
kubectl get storageclass
echo ""

# Detailed analysis of each PVC
if [ "$PVC_COUNT" -gt 0 ]; then
    echo "========================================="
    echo "  Detailed PVC Analysis"
    echo "========================================="
    echo ""
    
    kubectl get pvc -n "$NAMESPACE" -o json | jq -r '.items[].metadata.name' | while read -r PVC_NAME; do
        echo "📋 PVC: $PVC_NAME"
        echo "---"
        
        # Get PVC details
        PVC_JSON=$(kubectl get pvc "$PVC_NAME" -n "$NAMESPACE" -o json)
        
        STATUS=$(echo "$PVC_JSON" | jq -r '.status.phase')
        STORAGE_CLASS=$(echo "$PVC_JSON" | jq -r '.spec.storageClassName // "default"')
        REQUESTED_SIZE=$(echo "$PVC_JSON" | jq -r '.spec.resources.requests.storage')
        ACCESS_MODES=$(echo "$PVC_JSON" | jq -r '.spec.accessModes | join(", ")')
        VOLUME_NAME=$(echo "$PVC_JSON" | jq -r '.spec.volumeName // "unbound"')
        
        echo "Status: $STATUS"
        echo "Storage Class: $STORAGE_CLASS"
        echo "Requested Size: $REQUESTED_SIZE"
        echo "Access Modes: $ACCESS_MODES"
        echo "Bound to PV: $VOLUME_NAME"
        
        # Check if bound to a PV
        if [ "$VOLUME_NAME" != "unbound" ] && [ "$VOLUME_NAME" != "null" ]; then
            echo ""
            echo "PV Details:"
            kubectl get pv "$VOLUME_NAME" -o json | jq -r '"  Capacity: \(.spec.capacity.storage)\n  Reclaim Policy: \(.spec.persistentVolumeReclaimPolicy)\n  Status: \(.status.phase)"'
        fi
        
        # Check which pods use this PVC
        echo ""
        echo "Pods using this PVC:"
        PODS_USING_PVC=$(kubectl get pods -n "$NAMESPACE" -o json | \
            jq -r --arg pvc "$PVC_NAME" '.items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName == $pvc) | .metadata.name' || echo "")
        
        if [ -z "$PODS_USING_PVC" ]; then
            echo "  No pods currently using this PVC"
        else
            echo "$PODS_USING_PVC" | while read -r pod; do
                echo "  - $pod"
            done
        fi
        
        echo ""
        echo "---"
        echo ""
    done
fi

# Check for common storage issues
echo "========================================="
echo "  Common Issues Check"
echo "========================================="
echo ""

# Check for pending PVCs
PENDING_PVCS=$(kubectl get pvc -n "$NAMESPACE" -o json | jq -r '.items[] | select(.status.phase == "Pending") | .metadata.name')
if [ -n "$PENDING_PVCS" ]; then
    echo "⚠️  Pending PVCs detected:"
    echo "$PENDING_PVCS" | while read -r pvc; do
        echo "  - $pvc"
        echo "    Possible causes:"
        echo "      • No available PV matching the PVC requirements"
        echo "      • StorageClass provisioner not working"
        echo "      • Insufficient storage quota"
        echo "      • Access mode mismatch"
    done
    echo ""
fi

# Check for lost PVs
LOST_PVS=$(kubectl get pv -o json | jq -r '.items[] | select(.status.phase == "Failed" or .status.phase == "Released") | .metadata.name')
if [ -n "$LOST_PVS" ]; then
    echo "⚠️  PVs in Failed/Released state:"
    echo "$LOST_PVS" | while read -r pv; do
        echo "  - $pv ($(kubectl get pv "$pv" -o jsonpath='{.status.phase}'))"
    done
    echo ""
fi

# Check storage class provisioners
echo "🔧 Storage Class Provisioners:"
kubectl get storageclass -o json | jq -r '.items[] | "\(.metadata.name): \(.provisioner)"'
echo ""

# Recent storage-related events
echo "📅 Recent Storage Events:"
kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | grep -i "volume\|pvc\|pv\|storage" | tail -10 || echo "No recent storage events"
echo ""

echo "========================================="
echo "  Troubleshooting Suggestions"
echo "========================================="

if [ -n "$PENDING_PVCS" ]; then
    echo "1. For Pending PVCs:"
    echo "   kubectl describe pvc <pvc-name> -n $NAMESPACE"
    echo "   kubectl get events -n $NAMESPACE | grep <pvc-name>"
    echo "   kubectl get storageclass"
    echo ""
fi

echo "2. Check StorageClass configuration:"
echo "   kubectl describe storageclass <storage-class-name>"
echo ""

echo "3. Check PV availability:"
echo "   kubectl get pv"
echo "   kubectl describe pv <pv-name>"
echo ""

echo "4. Test volume mounting:"
echo "   Create a test pod with PVC and check if it mounts successfully"
echo ""

echo "5. Check CSI driver logs (if applicable):"
echo "   kubectl logs -n kube-system -l app=<csi-driver-name>"
