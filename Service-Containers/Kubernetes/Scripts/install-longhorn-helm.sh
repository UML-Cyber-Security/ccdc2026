#!/bin/bash

#Handling ERRORS because errors = BAD
cleanup_on_error() {
    echo ""
    echo "=========================================="
    echo "ERROR: EXITING IMMEDIATELY, DELETING LONGHORN"
    echo "=========================================="
    
    # Uninstall longhorn if it was downloaded :(
    helm uninstall longhorn -n longhorn 2>/dev/null || true
    
    # Deleting the longhorn namespace made for falco
    kubectl delete namespace longhorn 2>/dev/null || true
    
    # Removing the helm repo
    helm repo remove longhorn 2>/dev/null || true

    # I dont delete the helm binary cause this might already exist and I dont wanna cause problems
    
    echo "======================================="
    echo "EXITING | CLEANUP COMPLETE | START OVER"
    echo "======================================="
    exit 1
}
# Trap to call cleanup function on any error that occurs
trap cleanup_on_error ERR
# Exit if command fails
set -e

# Check if a package is installed
check_package() {
    if dpkg -l | grep -q "^ii  $1 "; then
        return 0
    else
        return 1
    fi
}

# Check if a service is running
check_service() {
    if systemctl is-active --quiet $1; then
        return 0
    else
        return 1
    fi
}


echo ""
echo "=================================================="
echo "=========CHECKING LONGHORN PREREQUISITES=========="
echo "=================================================="
echo ""
NEED_INSTALL=false
if ! check_package "open-iscsi"; then
    echo "open-iscsi NOT FOUND!!! INSTALLING NOW"
    NEED_INSTALL=true
fi

if ! check_package "nfs-common"; then
    echo "nfs-common NOT FOUND!!! INSTALLING NOW"
    NEED_INSTALL=true
fi

if ! check_service "iscsid"; then
    echo "iscsid service NOT RUNNING!!! ENABLING AND STARTING NOW"
    NEED_INSTALL=true
fi

if [ "$NEED_INSTALL" = true ]; then
    echo ""
    echo "=================================================="
    echo "===============INSTALLING PRE-REQS================"
    echo "=================================================="
    echo ""
    
    apt update
    apt install -y open-iscsi nfs-common
    systemctl enable --now iscsid
    
    echo ""
    echo "===================================================================="
    echo "PRE-REQS INSTALLED"
    echo "you MUST now reboot ALL nodes"
    echo "If swapoff disabled is not configured to be default" 
    echo "at start off run the command "sudo swapoff -a" right after restart"
    echo "===================================================================="
    exit 1
else
    echo ""
    echo "=================================================="
    echo "============PRE-REQS ALREADY INSTALLED============"
    echo "=================================================="
    echo ""
fi

echo ""
echo "=================================================="
echo "============ADDING LONGHORN HELM REPO============="
echo "=================================================="
echo ""
helm repo add longhorn https://charts.longhorn.io
echo ""
echo "=================================================="
echo "=======================DONE======================="
echo "=================================================="
echo ""


echo ""
echo "=================================================="
echo "===============UPDATING HELM INDEX================"
echo "=================================================="
echo ""
helm repo update
echo ""
echo "=================================================="
echo "=======================DONE======================="
echo "=================================================="
echo ""


echo ""
echo "=================================================="
echo "================CREATING NAMESPACE================"
echo "=================================================="
echo ""
kubectl create namespace longhorn
echo ""
echo "=================================================="
echo "=======================DONE======================="
echo "=================================================="
echo ""

echo ""
echo "=================================================="
echo "========ADDING LONGHORN CHART TO NAMESPACE========"
echo "=================================================="
echo ""
helm install longhorn longhorn/longhorn -n longhorn
echo ""
echo "=================================================="
echo "=======================DONE======================="
echo "=================================================="
echo ""

echo ""
echo "=================================================="
echo "===================LISTING PODS==================="
echo "===============PLEASE WAIT 1 MINUTE==============="
echo "=================================================="
echo ""
timeout 60 kubectl get pods -n longhorn -w
echo ""
echo "=================================================="
echo "=======================DONE======================="
echo "================HERE IS FULL LIST================="
echo "=================================================="
echo ""
kubectl get pods -n longhorn

echo ""
echo "===================================================================="
echo "======================= LISTING SERVICES ==========================="
echo "===================================================================="
kubectl get svc -n longhorn-system
echo ""
echo "=================================================="
echo "=================================================="
echo ""

echo ""
echo "========================================================================="
echo "======================== SETTING UP PORT FORWARD ========================"
echo "========================================================================="
echo "Starting a port forward as a background process: "
kubectl port-forward svc/longhorn-frontend -n longhorn-system 8081:80 &
PORT_FORWARD_PID=$!
echo "Port-forward started with PID: $PORT_FORWARD_PID"
echo ""
echo "=================================================="
echo "=================================================="
echo ""

echo "For this script to work for our current Nov2025 Infrastructure you need to do one thing"
echo "You need to set up an SSH tunnel to be able to access Longhorn from your local machine"
echo "On a new terminal run the command: "
echo "ssh -L 8081:localhost:8081 -J blueteam@<jumphost IP>:<jumphost port> blueteam@<master-node-ip>"
echo "Once you do that you can access the web ui"