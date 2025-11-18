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
echo "=================================================="
echo "=======MAKING SERVICE EXTERNALLY ACCESSIBLE======="
echo "=================================================="
echo ""
kubectl patch svc falco-falcosidekick-ui -n falco \
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
kubectl get svc -n falco
NODEPORT=$(kubectl get svc falco-falcosidekick-ui -n falco -o jsonpath='{.spec.ports[0].nodePort}')
echo "========================================================================================================================="
echo "                           GO TO LOCAL MACHINE BROWSER AT HTTP://localhost:$NODEPORT"
echo "                      HOW DID I GET THIS PORT? IT WILL BE IN THIS LINE FROM OUTPUT ABOVE"
echo "falco-falcosidekick-ui      NodePort      <CLUSTER IP>     <NONE>     <internal cluster port>:<nodeport port>/TCP    <AGE>"
echo "=========================================================================================================================="
echo ""
echo "For this script to work for our current Nov2025 Infrastructure you need to do one thing"
echo "You need to set up an SSH tunnel to be able to access Falcosidekick UI from your local machine, run the command:"
echo "ssh -L $NODEPORT:localhost:$NODEPORT -J blueteam@192.168.1.131:5001 blueteam@10.0.5.6"
echo "Once you do that you can access the web ui so if you havent already exit SSH and rejoin with that command"
echo ""
echo "Default Username: admin"
echo "Default Password: admin"

# IF THIS SCRIPT IS BROKEN MSG ME ON DISCORD AT green.u78"
