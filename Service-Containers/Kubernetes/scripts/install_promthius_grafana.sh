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
echo "==========INSTALLING PROMETHEUS WITH FOLLOWING RULES========"
echo "          - Persistent volumes disabled"
echo "          - Service Type: NodePort"
echo "============================================================"
echo ""
helm install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --set alertmanager.persistentVolume.enabled=false \
  --set server.persistentVolume.enabled=false \
  --set server.service.type=NodePort
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
echo "=================================================="
echo "=======MAKING SERVICE EXTERNALLY ACCESSIBLE======="
echo "=================================================="
echo ""
kubectl patch svc prometheus-server -n monitoring \
  -p '{"spec": {"type": "NodePort"}}'
echo ""
echo "=================================================="
echo "=======================DONE======================="
echo "=================================================="
echo ""

echo ""
echo "=================================================="
echo "========ACCESS THE MACHINE AT PORT LISTED========="
echo "=================================================="
echo ""
kubectl get svc -n monitoring
PROMETHEUS_NODEPORT=$(kubectl get svc prometheus-server -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
echo ""
echo "========================================================================================================================="
echo "                           GO TO LOCAL MACHINE BROWSER AT HTTP://localhost:$PROMETHEUS_NODEPORT"
echo "                      HOW DID I GET THIS PORT? IT WILL BE IN THIS LINE FROM OUTPUT ABOVE"
echo "  prometheus-server      NodePort      <CLUSTER IP>     <NONE>     <internal cluster port>:<nodeport port>/TCP    <AGE>  "
echo "=========================================================================================================================="
echo ""
echo "For this script to work for our current Nov2025 Infrastructure you need to do one thing"
echo "You need to set up an SSH tunnel to be able to access Promethius UI from your local machine, run the command:"
echo "ssh -L $PROMETHEUS_NODEPORT:localhost:$PROMETHEUS_NODEPORT -J blueteam@192.168.1.131:5001 blueteam@10.0.5.6"
echo "Once you do that you can access the web ui so if you havent already exit SSH and rejoin with that command"
echo ""

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
echo "=================================================="
echo "=======MAKING SERVICE EXTERNALLY ACCESSIBLE======="
echo "=================================================="
echo ""
kubectl patch svc grafana -n monitoring \
  -p '{"spec": {"type": "NodePort"}}'
echo ""
echo "=================================================="
echo "=======================DONE======================="
echo "=================================================="
echo ""

echo ""
echo "=================================================="
echo "========ACCESS THE MACHINE AT PORT LISTED========="
echo "=================================================="
echo ""
kubectl get svc -n monitoring
GRAFANA_NODEPORT=$(kubectl get svc grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
echo ""
echo "=========================================================================================================================="
echo "                           GO TO LOCAL MACHINE BROWSER AT HTTP://localhost:$GRAFANA_NODEPORT"
echo "                      HOW DID I GET THIS PORT? IT WILL BE IN THIS LINE FROM OUTPUT ABOVE"
echo "        grafana      NodePort      <CLUSTER IP>     <NONE>     <internal cluster port>:<nodeport port>/TCP    <AGE>        "
echo "==========================================================================================================================="
echo ""
echo "For this script to work for our current Nov2025 Infrastructure you need to do one thing"
echo "You need to set up an SSH tunnel to be able to access Grafana from your local machine, run the command:"
echo "ssh -L $GRAFANA_NODEPORT:localhost:$GRAFANA_NODEPORT -J blueteam@192.168.1.131:5001 blueteam@10.0.5.6"
echo "Once you do that you can access the web ui so if you havent already exit SSH and rejoin with that command"
echo ""