#!/bin/bash

#Handling ERRORS because errors = BAD
cleanup_on_error() {
    echo ""
    echo "==========================================="
    echo "ERROR: EXITING IMMEDIATELY, DELETING ARGOCD"
    echo "==========================================="
    # Deleting the ArgoCD stuff
    kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml 2>/dev/null || true
    kubectl delete namespace argocd 2>/dev/null || true

    echo "======================================="
    echo "EXITING | CLEANUP COMPLETE | START OVER"
    echo "======================================="
    exit 1
}

# Trap to call cleanup function on any error that occurs
trap cleanup_on_error ERR

# Exit if command fails
set -e


echo "For this script to work for our current Nov2025 Infrastructure you need to do one thing"
echo "You need to set up an SSH tunnel to be able to access ArgoCD from your local machine, run the command:"
echo "ssh -L 8080:localhost:8080 -J blueteam@192.168.1.131:5001 blueteam@10.0.5.6"
echo "Once you do that the script going forward will work"
while true; do 
    echo "If you ARE NOT running the SSH tunnel type 'q' to quit"
    echo "If you ARE running the SSH tunnel type 'c' to continue"
    read -p "Enter choice: " choice
    case "$choice" in
        q|Q)
            echo "Exiting..."
            exit 0
            ;;
       c|C)
            echo "ALRIGHT LETS CONTINUE"
            break
            ;;
        *)
            echo "Invalid input. Please type q or c."
            ;;
    esac
done

echo "========================================================================="
echo "======================= CREATING ARGOCD NAMESPACE ======================="
echo "========================================================================="
kubectl create namespace argocd
echo ""
echo "=================================================="
echo "=======================DONE======================="
echo "=================================================="
echo ""


echo "=========================================================================================="
echo "======================= DEPLOYING ARGOCD COMPONENTS INTO NAMESPACE ======================="
echo "=========================================================================================="
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
echo ""
echo "=================================================="
echo "=======================DONE======================="
echo "=================================================="
echo ""

echo "=========================================================================================="
echo "======================= WAITING FOR PODS TO BE READY ======================="
echo "=========================================================================================="
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=120s
echo ""
echo "=================================================="
echo "=======================DONE======================="
echo "=================================================="

echo "===================================================================="
echo "======================= LISTING SERVICES =========================="
echo "===================================================================="
kubectl get svc -n argocd
echo ""
echo "=================================================="
echo "=================================================="
echo ""


echo ""
echo "===================================================================="
echo "========================= GETTING PASSWORD ========================="
echo "===================================================================="
echo -n "Password: "; kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
echo "Default Username: admin"
echo ""
echo "=================================================="
echo "=================================================="
echo ""

echo "========================================================================="
echo "================= SETTING UP PORT FORWARD TO ARGOCD ===================="
echo "========================================================================="
echo "Starting port-forward as background process"
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
PORT_FORWARD_PID=$!
echo "Port-forward started with PID: $PORT_FORWARD_PID"
echo ""
echo "=================================================="
echo "=================================================="
echo ""

echo "========================================================================="
echo "========================= ACCESS INSTRUCTIONS =========================="
echo "========================================================================="
echo ""
echo "  1. Make sure this SSH tunnel is running in a terminal:"
echo "     ssh -L 8080:localhost:8080 -J blueteam@<jumphost IP>:<jumphost port> blueteam@<master-node-ip>"
echo ""
echo "  2. Open your browser and go to: https://localhost:8080"
echo ""
