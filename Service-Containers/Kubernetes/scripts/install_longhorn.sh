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
echo "=================================================="
echo "=======MAKING SERVICE EXTERNALLY ACCESSIBLE======="
echo "=================================================="
echo ""
kubectl patch svc longhorn-frontend -n longhorn \
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
kubectl get svc -n longhorn
NODEPORT=$(kubectl get svc longhorn-frontend -n longhorn -o jsonpath='{.spec.ports[0].nodePort}')
echo "====================================================================================================================="
echo "                           GO TO LOCAL MACHINE BROWSER AT HTTP://localhost:$NODEPORT                                 "
echo "                      HOW DID I GET THIS PORT? IT WILL BE IN THIS LINE FROM OUTPUT ABOVE                           "
echo "longhorn-frontend      NodePort      <CLUSTER IP>     <NONE>     <internal cluster port>:<nodeport port>/TCP    <AGE>"
echo "====================================================================================================================="
echo ""

echo "For this script to work for our current Nov2025 Infrastructure you need to do one thing"
echo "You need to set up an SSH tunnel to be able to access Longhorn from your local machine, run the command:"
echo "ssh -L $NODEPORT:localhost:$NODEPORT -J blueteam@192.168.1.131:5001 blueteam@10.0.5.6"
echo "Once you do that you can access the web ui so if you havent already exit SSH and rejoin with that command"

# IF THIS SCRIPT IS BROKEN MSG ME ON DISCORD AT green.u78"