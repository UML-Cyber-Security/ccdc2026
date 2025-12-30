#!/bin/bash

#Handling ERRORS because errors = BAD
cleanup_on_error() {
    echo ""
    echo "=========================================="
    echo "ERROR: EXITING IMMEDIATELY, DELETING FALCO"
    echo "=========================================="
    
    # Uninstall Falco if it was downloaded :(
    helm uninstall falco -n falco 2>/dev/null || true
    
    # Deleting the falco namespace made for falco
    kubectl delete namespace falco 2>/dev/null || true
    
    # Removing the helm repo
    helm repo remove falcosecurity 2>/dev/null || true

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

# Install helm if you havent already
if ! command -v helm &> /dev/null; then
    echo "INSTALLING HELM" 
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
    echo ""
    echo "=================================================="
    echo "=======================DONE======================="
    echo "=================================================="
    echo ""
else 
    echo "============================================================"
    echo "===================HELM ALREADY INSTALLED==================="
    echo "============================================================"
    echo ""
fi

echo "Adding FALCO Helm chart repository & updating"
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

echo ""
echo "=================================================="
echo "=======================DONE======================="
echo "=================================================="
echo ""


echo "Beginning to install FALCO using Helm"

  # The first "set" command disables Falscos automatic rule and plugin downloader 
  # It was causing me issues so I just disabled it, if it aint broke dont fix it mentality
  # The second "set" command disables continuous syncing of the Falco plugins
helm install falco falcosecurity/falco \
  --namespace falco --create-namespace \
  --set falcoctl.artifact.install.enabled=false \
  --set falcoctl.artifact.follow.enabled=false

echo ""
echo "=================================================="
echo "=======================DONE======================="
echo "=================================================="
echo ""

echo "Waiting for all pods to be ready in the new FALCO namespace"

kubectl wait pod --for=condition=Ready --all -n falco --timeout=300s

echo ""
echo "=================================================="
echo "=======================DONE======================="
echo "=================================================="
echo ""

echo "Showing current status of pods running in FALCO namespace"

kubectl get pods -n falco

echo ""
echo "=================================================="
echo "=======================DONE======================="
echo "=================================================="
echo ""
