#!/bin/bash
exit_on_error() {
    echo ""
    echo "=========================================="
    echo "        ERROR: EXITING IMMEDIATELY        "
    echo "=========================================="
    
    echo "========================================"
    echo " EXITING | | | | | | | | | | START OVER "
    echo "========================================"
    exit 1
}
# Trap to call cleanup function on any error that occurs
trap exit_on_error ERR
# Exit if command fails
set -e

if ! command -v helm &> /dev/null; then
    echo ""
    echo "=================================================="
    echo "================INSTALLING HELM==================="
    echo "=================================================="
    echo ""
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
    echo ""
    echo "=================================================="
    echo "=======================DONE======================="
    echo "=================================================="
    echo ""
else 
    echo ""
    echo "==================================================="
    echo "===============HELM ALREADY EXISTS================="
    echo "==================================================="
    echo ""
fi

echo ""
echo "=================================================="
echo "===========CHECKING IF FALCO IS INSTALLED========="
echo "=================================================="
echo ""
if helm list -n falco | grep -q "^falco"; then
    echo ""
    echo "=================================================="
    echo "===========FALCO EXISTS ADDING SIDEKICK==========="
    echo "=================================================="
    echo ""
    helm upgrade --namespace falco falco falcosecurity/falco \
      --set falcosidekick.enabled=true \
      --set falcosidekick.webui.enabled=true \
      --set falcosidekick.webui.redis.storageEnabled=false
    echo ""
    echo "=================================================="
    echo "=======================DONE======================="
    echo "=================================================="
    echo ""
else
    echo ""
    echo "=================================================="
    echo "============INSTALLING FALCO WITH HELM============"
    echo "=================================================="
    echo ""
    helm repo add falcosecurity https://falcosecurity.github.io/charts
    helm repo update
    helm install falco falcosecurity/falco \
      --namespace falco \
      --create-namespace \
      --set falcosidekick.enabled=true \
      --set falcosidekick.webui.enabled=true \
      --set falcosidekick.webui.redis.storageEnabled=false \
      --set falcoctl.artifact.install.enabled=false \
      --set falcoctl.artifact.follow.enabled=false
    echo ""
    echo "=================================================="
    echo "=======================DONE======================="
    echo "=================================================="
    echo ""
fi

echo ""
echo "==================================================="
echo "===================LISTING PODS===================="
echo "===============PLEASE WAIT 2 MINUTES==============="
echo "==================================================="
echo ""
kubectl wait pod --for=condition=Ready --all -n falco --timeout=120s
echo ""
echo "=================================================="
echo "=======================DONE======================="
echo "================HERE IS FULL LIST================="
echo "=================================================="
echo ""
kubectl get pods -n falco

echo ""
echo "===================================================================="
echo "======================= LISTING SERVICES ==========================="
echo "===================================================================="
kubectl get svc -n falco
echo ""
echo "=================================================="
echo "=================================================="
echo ""

echo ""
echo "========================================================================="
echo "========================== SETTING UP PORT FORWARD ======================"
echo "========================================================================="
echo "Starting port-forward as background process"
kubectl port-forward svc/falco-falcosidekick-ui -n falco 8084:2802 &
PORT_FORWARD_PID=$!
echo "Port-forward started with PID: $PORT_FORWARD_PID"
echo ""
echo "=================================================="
echo "=================================================="
echo ""

echo "========================================================================="
echo "========================= ACCESSING SERVICE=========================="
echo "========================================================================="
echo ""
echo "  1. Make sure your SSH tunnel is running in another terminal:"
echo "     ssh -L 8084:localhost:8084 -J blueteam@<jumphost IP>:<jumphost port> blueteam@<master-node-ip>"
echo ""
echo "  2. Open your browser and go to: http://localhost:8084"
echo ""
echo "  3. Login with admin as both username and password"
echo ""
echo "========================================================================="
echo ""
echo "To stop the port-forward , run: kill $PORT_FORWARD_PID"
echo ""
echo "========================================================================="