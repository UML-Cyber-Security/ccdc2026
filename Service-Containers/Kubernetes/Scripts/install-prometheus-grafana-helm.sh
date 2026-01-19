#!/bin/bash

#Handling ERRORS because errors = BAD
cleanup_on_error() {
    echo ""
    echo "======================================================================="
    echo "ERROR: EXITING IMMEDIATELY, DELETING EVERYTHING THAT MAY HAVE BEEN DONE"
    echo "======================================================================="
    
    # Uninstall Grafana/Prometheus if it was downloaded :(
    helm uninstall prometheus -n monitoring 2>/dev/null || true
    helm uninstall grafana -n monitoring 2>/dev/null || true    
      
    # Removing the helm repo
    helm repo remove prometheus-community 2>/dev/null || true
    helm repo remove grafana 2>/dev/null || true
    # I dont delete the helm binary cause this might already exist and I dont wanna cause problems
    # I also wont delete the monitoring namespace because it lowk might be in use for smth else
    echo "======================================="
    echo "EXITING | CLEANUP COMPLETE | START OVER"
    echo "======================================="
    exit 1
}
# Trap to call cleanup function on any error that occurs
trap cleanup_on_error ERR
# Exit if command fails LOL
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
    echo "====================   DONE   ===================="
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
echo "====================================================="
echo "===========CHECKING IF LONGHORN IS INSTALLED========="
echo "====================================================="
echo ""
if helm list -n longhorn | grep -q "^longhorn"; then
    echo ""
    echo ""
    echo ""
    echo "=================================================="
    echo "============LONGHORN EXISTS, MOVING ON============"
    echo "=================================================="
    echo ""
    echo ""
    echo ""
    #continue 
else
    echo ""
    echo "========================================================"
    echo "LONGHORN IS NOT INSTALLED, INSTALL LONGHORN THEN PROCEED"
    echo "    There is a longhorn script on the CCDC26 github     "
    echo " Install Longhorn/Run the script then come back to this "
    echo "========================================================"
    echo ""
    exit 1
fi
echo ""
echo "=================================================="
echo "==========CREATING MONITORING NAMESPACE==========="
echo "=================================================="
echo ""
kubectl create namespace monitoring 
echo ""
echo "=================================================="
echo "====================   DONE   ===================="
echo "=================================================="
echo ""

echo ""
echo "==================================================="
echo "=========ADDING PROMETHIUS HELM CHART REPO========="
echo "==================================================="
echo ""
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
echo ""
echo "=================================================="
echo "====================   DONE   ===================="
echo "=================================================="
echo ""


echo ""
echo "======================================================="
echo "==================UPDATING HELM REPOS=================="
echo "======================================================="
echo ""
helm repo update
echo ""
echo "=================================================="
echo "====================   DONE   ===================="
echo "=================================================="
echo ""

echo ""
echo "============================================================"
echo "========INSTALLING PROMETHEUS IN MONITORING NAMESPACE======="
echo "============================================================"
echo ""
helm install prometheus prometheus-community/prometheus \
  --namespace monitoring \
echo ""
echo "========================================================="
echo "=======================   DONE   ========================"
echo "========================================================="
echo ""

echo ""
echo "==================================================="
echo "===================LISTING PODS===================="
echo "===============PLEASE WAIT 2 MINUTES==============="
echo "==================================================="
echo ""
kubectl wait pod --for=condition=Ready --all -n monitoring --timeout=120s
echo ""
echo "=================================================="
echo "=======================DONE======================="
echo "================HERE IS FULL LIST================="
echo "=================================================="
echo ""
kubectl get pods -n monitoring

echo ""
echo "===================================================="
echo "===========ADDING GRAFANA HELM CHART REPO==========="
echo "===================================================="
echo ""
helm repo add grafana https://grafana.github.io/helm-charts
echo ""
echo "=================================================="
echo "====================   DONE   ===================="
echo "=================================================="
echo ""

echo ""
echo "============================================================"
echo "==========           INSTALLING GRAFANA           =========="
echo "============================================================"
echo ""
helm install grafana grafana/grafana --namespace monitoring
echo ""
echo "========================================================="
echo "=======================   DONE   ========================"
echo "========================================================="
echo ""

echo "===================================================================="
echo "========================= GETTING PASSWORD ========================="
echo "===================================================================="
echo -n "Password: "; kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
echo ""
echo "=================================================="
echo "=======================DONE======================="
echo "=================================================="
echo ""

echo ""
echo "===================================================================="
echo "======================= LISTING SERVICES ==========================="
echo "===================================================================="
kubectl get svc -n monitoring
echo ""
echo "=================================================="
echo "=================================================="
echo ""

echo ""
echo "========================================================================="
echo "================= SETTING UP PORT FORWARDS =============================="
echo "========================================================================="
echo "Starting Prometheus & Grafana port forwards as background processes"
kubectl port-forward svc/prometheus-server -n monitoring 8082:80 &
PROMETHEUS_PID=$!
echo "Prometheus port-forward started with PID: $PROMETHEUS_PID"
echo ""
kubectl port-forward svc/grafana -n monitoring 8083:80 &
GRAFANA_PID=$!
echo "Grafana port-forward started with PID: $GRAFANA_PID"
echo ""
echo "=================================================="
echo "=================================================="
echo ""

echo "========================================================================="
echo "========================== ACCESSING SERVICES ==========================="
echo "========================================================================="
echo ""
echo "  PROMETHEUS:"
echo "  1. Make sure an SSH tunnel is running in a terminal:"
echo "     ssh -L 8082:localhost:8082 -J blueteam@<jumphost IP>:<jumphost port> blueteam@<master-node-ip>"
echo ""
echo "  2. Open your browser and go to: http://localhost:8082"
echo ""
echo "========================================================================="
echo ""
echo "  GRAFANA:"
echo "  --------"
echo "  1. Make sure an SSH tunnel is running in a seperate terminal:"
echo "     ssh -L 8083:localhost:8083 -J blueteam@<jumphost IP>:<jumphost port> blueteam@<master-node-ip>"
echo ""
echo "  2. Open your browser and go to: http://localhost:8083"
echo ""
echo "========================================================================="
