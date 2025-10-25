Headlamp: UI to manage a Kubernetes cluster
Prerequisites: Have a Kubernetes cluster setup and install Headlamp.
Author: Julian Henry
Purpose: Documentation for 2026 CCDC UML.
How to Set up Headlamp on your Local Machine for a Remote Kubernetes Cluster
First, SSH into the Kubernetes master node.

ssh -L 6443:10.0.2.26:6443 blueteam@192.168.1.100

The -L creates a local port forwarding tunnel. The above command uses local port 6443 on your machine to create a tunnel between your machine and the remote host, 10.0.2.26 on port 6443, and then SSH’s in. This SSH session will need to be kept running to view the cluster in Headlamp

On the master node, run this command:

cat ~/.kube/config

Check the home directory and view the contents of the kubernetes cluster config file.

Copy that file to your local machine and save it as kubeconfig (technically could be named anything you want) and add/edit these configurations:
    server: https://localhost:[COPY PORT]
    insecure-skip-tls-verify: true


On the master node, run this command:

kubectl create token headlamp-admin -n kube-system

This creates an authentication token that you may need for Headlamp. Save this for later. Keep the SSH session running in the background or you won’t be able to access the cluster in Headlamp.

In Headlamp -> Add Cluster -> Load from KubeConfig.

If you get “bad gateway”, you need to comment out the “certificate-authority-data:” configuration, because you cannot use that and also set insecure-skip-tls-verify to true.

Now Headlamp is set up and you can view your cluster.
