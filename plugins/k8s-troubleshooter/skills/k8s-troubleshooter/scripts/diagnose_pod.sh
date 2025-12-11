#!/bin/bash
# diagnose_pod.sh - Comprehensive pod troubleshooting

set -euo pipefail

NAMESPACE="${1:-default}"
POD_NAME="${2:-}"

if [ -z "$POD_NAME" ]; then
    echo "Usage: $0 <namespace> <pod-name>"
    exit 1
fi

echo "========================================="
echo "  Pod Diagnosis: $POD_NAME"
echo "  Namespace: $NAMESPACE"
echo "========================================="
echo ""

# Check if pod exists
if ! kubectl get pod "$POD_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "❌ Pod not found: $POD_NAME in namespace $NAMESPACE"
    echo ""
    echo "Available pods in namespace:"
    kubectl get pods -n "$NAMESPACE"
    exit 1
fi

# Basic pod information
echo "📊 Pod Status:"
kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o wide
echo ""

# Detailed pod description
echo "📋 Pod Description:"
kubectl describe pod "$POD_NAME" -n "$NAMESPACE" | head -50
echo ""

# Container statuses
echo "📦 Container Status:"
kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o json | \
    jq -r '.status.containerStatuses[]? | "Container: \(.name)\nReady: \(.ready)\nRestart Count: \(.restartCount)\nState: \(.state | keys[0])"'
echo ""

# Recent events
echo "📅 Recent Events:"
kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$POD_NAME" \
    --sort-by='.lastTimestamp' | tail -10
echo ""

# Resource usage
echo "💾 Resource Usage:"
kubectl top pod "$POD_NAME" -n "$NAMESPACE" 2>/dev/null || echo "Metrics not available"
echo ""

# Check logs
echo "📜 Recent Logs (last 20 lines):"
kubectl logs "$POD_NAME" -n "$NAMESPACE" --tail=20 --all-containers=true 2>/dev/null || \
    echo "No logs available or pod hasn't started"
echo ""

# Common issues check
echo "🔍 Common Issues Analysis:"

# Check for image pull errors
if kubectl describe pod "$POD_NAME" -n "$NAMESPACE" | grep -q "ErrImagePull\|ImagePullBackOff"; then
    echo "⚠️  Image Pull Issue Detected!"
    echo "   Check: - Image name and tag"
    echo "         - Image pull secrets"
    echo "         - Registry accessibility"
fi

# Check for crash loops
if kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o json | jq -r '.status.containerStatuses[].state' | grep -q "CrashLoopBackOff"; then
    echo "⚠️  CrashLoopBackOff Detected!"
    echo "   Check: - Application logs"
    echo "         - Liveness/Readiness probes"
    echo "         - Resource limits"
fi

# Check for pending state
POD_PHASE=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
if [ "$POD_PHASE" = "Pending" ]; then
    echo "⚠️  Pod is Pending!"
    echo "   Possible causes:"
    echo "   - Insufficient resources"
    echo "   - PVC not bound"
    echo "   - Node selector/affinity issues"
    
    # Check for unschedulable conditions
    kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o json | \
        jq -r '.status.conditions[]? | select(.type=="PodScheduled" and .status=="False") | "   Reason: \(.reason)\n   Message: \(.message)"'
fi

# Check for resource issues
REQUESTS=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o json | \
    jq -r '.spec.containers[].resources.requests // {} | to_entries | map("\(.key)=\(.value)") | join(", ")')
if [ -n "$REQUESTS" ]; then
    echo ""
    echo "📊 Resource Requests: $REQUESTS"
fi

echo ""
echo "========================================="
echo "  Suggested Actions"
echo "========================================="

# Provide contextual suggestions
if kubectl describe pod "$POD_NAME" -n "$NAMESPACE" | grep -q "Back-off pulling image"; then
    echo "1. Fix image pull issue:"
    echo "   kubectl set image pod/$POD_NAME <container>=<correct-image> -n $NAMESPACE"
fi

if [ "$POD_PHASE" = "Pending" ]; then
    echo "2. Check node resources:"
    echo "   kubectl top nodes"
    echo "   kubectl describe nodes"
fi

echo ""
echo "For more detailed debugging:"
echo "- Shell into pod: kubectl exec -it $POD_NAME -n $NAMESPACE -- /bin/bash"
echo "- Get full logs: kubectl logs $POD_NAME -n $NAMESPACE --all-containers=true"
echo "- Watch events: kubectl get events -n $NAMESPACE -w"
