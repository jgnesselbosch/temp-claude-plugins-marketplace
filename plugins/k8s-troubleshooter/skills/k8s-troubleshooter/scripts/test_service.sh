#!/bin/bash
# test_service.sh - Test Kubernetes service connectivity and configuration

set -euo pipefail

NAMESPACE="${1:-default}"
SERVICE_NAME="${2:-}"

if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: $0 <namespace> <service-name>"
    exit 1
fi

echo "========================================="
echo "  Service Testing: $SERVICE_NAME"
echo "  Namespace: $NAMESPACE"
echo "========================================="
echo ""

# Check if service exists
if ! kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "❌ Service not found: $SERVICE_NAME in namespace $NAMESPACE"
    echo ""
    echo "Available services in namespace:"
    kubectl get services -n "$NAMESPACE"
    exit 1
fi

# Service details
echo "📋 Service Information:"
kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" -o wide
echo ""

# Service description
echo "📝 Service Details:"
kubectl describe service "$SERVICE_NAME" -n "$NAMESPACE"
echo ""

# Check endpoints
echo "🔗 Service Endpoints:"
ENDPOINTS=$(kubectl get endpoints "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
if [ -z "$ENDPOINTS" ]; then
    echo "⚠️  WARNING: No endpoints found! Service has no backing pods."
    echo ""
    echo "Checking for matching pods..."
    SELECTOR=$(kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.selector}' | jq -r 'to_entries | map("\(.key)=\(.value)") | join(",")')
    if [ -n "$SELECTOR" ]; then
        echo "Service selector: $SELECTOR"
        kubectl get pods -n "$NAMESPACE" -l "$SELECTOR"
    fi
else
    kubectl get endpoints "$SERVICE_NAME" -n "$NAMESPACE"
    echo ""
    echo "✅ Endpoints found: $ENDPOINTS"
fi
echo ""

# Service type specific checks
SERVICE_TYPE=$(kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.type}')
echo "📦 Service Type: $SERVICE_TYPE"

case "$SERVICE_TYPE" in
    "LoadBalancer")
        echo ""
        echo "🌐 LoadBalancer Configuration:"
        EXTERNAL_IP=$(kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        EXTERNAL_HOSTNAME=$(kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
        
        if [ -n "$EXTERNAL_IP" ]; then
            echo "External IP: $EXTERNAL_IP"
        elif [ -n "$EXTERNAL_HOSTNAME" ]; then
            echo "External Hostname: $EXTERNAL_HOSTNAME"
        else
            echo "⚠️  LoadBalancer external address is pending..."
        fi
        ;;
    "NodePort")
        echo ""
        echo "🔌 NodePort Configuration:"
        NODE_PORTS=$(kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ports[*].nodePort}')
        echo "NodePorts: $NODE_PORTS"
        ;;
    "ClusterIP")
        CLUSTER_IP=$(kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}')
        echo "Cluster IP: $CLUSTER_IP"
        ;;
esac
echo ""

# DNS test
echo "🔍 DNS Resolution Test:"
echo "Testing DNS resolution from within cluster..."

# Create a test pod for DNS lookup
TEST_POD="dns-test-$(date +%s)"
kubectl run "$TEST_POD" --image=busybox --rm -i --restart=Never --namespace="$NAMESPACE" -- \
    nslookup "$SERVICE_NAME.$NAMESPACE.svc.cluster.local" 2>&1 || echo "DNS test failed"
echo ""

# Port connectivity test
echo "🔌 Port Configuration:"
PORTS=$(kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ports[*].port}')
TARGET_PORTS=$(kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ports[*].targetPort}')
PROTOCOLS=$(kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ports[*].protocol}')

echo "Service Ports: $PORTS"
echo "Target Ports: $TARGET_PORTS"
echo "Protocols: $PROTOCOLS"
echo ""

# Check for common issues
echo "⚠️  Common Issues Check:"

# Check selector matches pods
SELECTOR=$(kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.selector}')
if [ -z "$SELECTOR" ] || [ "$SELECTOR" = "{}" ]; then
    echo "❌ Service has no selector! Cannot route traffic to pods."
else
    SELECTOR_LABEL=$(echo "$SELECTOR" | jq -r 'to_entries | map("\(.key)=\(.value)") | join(",")')
    POD_COUNT=$(kubectl get pods -n "$NAMESPACE" -l "$SELECTOR_LABEL" --no-headers 2>/dev/null | wc -l)
    
    if [ "$POD_COUNT" -eq 0 ]; then
        echo "❌ No pods match service selector: $SELECTOR_LABEL"
        echo "   Create pods with matching labels"
    else
        echo "✅ Found $POD_COUNT pod(s) matching selector"
    fi
fi
echo ""

# Recent events
echo "📅 Recent Events:"
kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$SERVICE_NAME" \
    --sort-by='.lastTimestamp' 2>/dev/null | tail -5 || echo "No recent events"
echo ""

echo "========================================="
echo "  Troubleshooting Suggestions"
echo "========================================="

if [ -z "$ENDPOINTS" ]; then
    echo "1. Service has no endpoints:"
    echo "   - Verify pods exist with matching labels"
    echo "   - Check pod readiness probes"
    echo "   - Ensure targetPort matches container port"
fi

if [ "$SERVICE_TYPE" = "LoadBalancer" ] && [ -z "$EXTERNAL_IP" ] && [ -z "$EXTERNAL_HOSTNAME" ]; then
    echo "2. LoadBalancer external address pending:"
    echo "   - Check cloud provider integration"
    echo "   - Verify LoadBalancer service quota"
    echo "   - Check cluster events: kubectl get events -A"
fi

echo ""
echo "Additional debugging commands:"
echo "- Test from another pod: kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://$SERVICE_NAME.$NAMESPACE.svc.cluster.local"
echo "- Check service logs: kubectl logs -l <selector> -n $NAMESPACE"
echo "- Port forward for testing: kubectl port-forward svc/$SERVICE_NAME -n $NAMESPACE <local-port>:<service-port>"
