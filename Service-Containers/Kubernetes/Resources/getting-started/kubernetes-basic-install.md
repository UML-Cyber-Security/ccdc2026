# Setting up Kubernetes - Proxmox

## Things to Consider

- If you don't understand how Kubernetes works, I would advise reading documentation on the theory before moving onto the implementation
- This documentation will assume 1 master node and 3 worker nodes

## What You Need Before Starting

- 4 Ubuntu Server machines running with:
  - 4 gigabytes of RAM
  - 32 gigabytes of disk space
  - 2 cores for the worker nodes
  - 4 cores for the master node

---

## Step 1: Configure Hostnames | ALL NODES

### Part A: Set Hostnames

In each of the machines, modify the hostnames to something recognizable.

I changed the hostname of the master node to "k8s-master-node" by running the command:
```bash
sudo hostnamectl set-hostname "k8s-master-node"
```

I then changed the hostname of the 1st worker node to "k8s-worker-node-1" by running the command:
```bash
sudo hostnamectl set-hostname "k8s-worker-node-1"
```

Do the same for the other 2 worker nodes.

For the changes to go through, run the following command on EVERY machine:
```bash
exec bash
```

To verify the changes, run the following command on EVERY machine:
```bash
hostname
```

### Part B: Update /etc/hosts File

Update the `/etc/hosts` file and add the IP addresses and hostnames for the Master Node and worker nodes by running the following command:
```bash
sudo nano /etc/hosts
```

Once in the file, change it like below but replace the example IP and example hostname to match the IPs and hostnames of your machines you set in Step 1 Part A:
```
127.0.0.1 localhost
127.0.1.1 ccdc

192.168.1.211 k8s-master-node
192.168.1.189 k8s-worker-node-1
192.168.0.120 k8s-worker-node-2
192.168.0.121 k8s-worker-node-3
```

To ensure you can communicate to all the nodes in the cluster, from each node ping every machine using their hostname by running the following command:
```bash
ping -c 3 k8s-worker-node-1
```

The result should look like this:
```
PING k8s-worker-node-1 (192.168.1.189) 56(84) bytes of data.
64 bytes from k8s-worker-node-1 (192.168.1.189): icmp_seq=1 ttl=64 time=0.156 ms
64 bytes from k8s-worker-node-1 (192.168.1.189): icmp_seq=2 ttl=64 time=0.234 ms
64 bytes from k8s-worker-node-1 (192.168.1.189): icmp_seq=3 ttl=64 time=0.189 ms
```

---

## Step 2: Disable Swap Space | ALL NODES

### Part A: Disable Swap

To disable swap on the nodes, run the following command:
```bash
sudo swapoff -a
```

To check if swap has been disabled:
```bash
swapon --show
```

To persist the change, run the following command to access & change the `/etc/fstab` file:
```bash
sudo nano /etc/fstab
```

In the file, comment out the '/swap.img' line as shown below:
```
# /swap.img     none    swap    sw      0       0
```

If the output of `swapon --show` is blank, swap space has been disabled.

---

## Step 3: Load the Containerd Modules | ALL NODES

### Part A: Enable and Load Modules

To enable and load modules, run the following commands on ALL machines:
```bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

Then create a configuration file to specify the modules to load them permanently using the following command on ALL machines:
```bash
sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
```

---

## Step 4: Configure the IPv4 Networking | ALL NODES

### Part A: Create Kubernetes Configuration

Create a K8s configuration file in the `/etc/sysctl.d/` directory with the following command:
```bash
sudo nano /etc/sysctl.d/k8s.conf
```

Then add these lines in the `k8s.conf` file:
```
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
```

Apply these settings by running the following command:
```bash
sudo sysctl --system
```

---

## Step 5: Installing Docker | ALL NODES

### Part A: Install Docker

To install Docker from Ubuntu's default repos, run these commands on ALL machines:
```bash
sudo apt update
sudo apt install docker.io -y
```

To verify if Docker is running, run the following command on ALL machines:
```bash
sudo systemctl status docker
```

The output should show Docker as active (running).

If Docker is not active, run the following command:
```bash
sudo systemctl start docker
```

Also, enable the Docker daemon for AutoStart upon system startup with the following command:
```bash
sudo systemctl enable docker
```

### Part B: Configure Containerd

Now we need to configure containerd. Begin by creating the `/etc/containerd` directory by running the following command:
```bash
sudo mkdir /etc/containerd
```

Then create the default config file for containerd by running:
```bash
sudo sh -c "containerd config default > /etc/containerd/config.toml"
```

Then open and edit the config file:
```bash
sudo nano /etc/containerd/config.toml
```

Find and update the `SystemdCgroup` directive by setting it to `true`. You can also use sed:
```bash
sudo sed -i 's/ SystemdCgroup = false/ SystemdCgroup = true/' /etc/containerd/config.toml
```

The configuration should include these settings:
```toml
[plugins]

  [plugins."io.containerd.gc.v1.scheduler"]
    deletion_threshold = 0
    mutation_threshold = 100
    pause_threshold = 0.02
    schedule_delay = "0s"
    startup_delay = "100ms"

  [plugins."io.containerd.grpc.v1.cri"]
    cdi_spec_dirs = ["/etc/cdi", "/var/run/cdi"]
    device_ownership_from_security_context = false
    disable_apparmor = false
    disable_cgroup = false
    disable_hugetlb_controller = true
    disable_proc_mount = false
    disable_tcp_service = true
    drain_exec_sync_io_timeout = "0s"
    enable_cdi = false
    enable_selinux = false
    enable_tls_streaming = false
    enable_unprivileged_icmp = false
    enable_unprivileged_ports = false
    ignore_deprecation_warnings = []
    ignore_image_defined_volumes = false
    image_pull_progress_timeout = "5m0s"
    image_pull_with_sync_fs = false
    max_concurrent_downloads = 3
    max_container_log_line_size = 16384
    netns_mounts_under_state_dir = false
    restrict_oom_score_adj = false
    sandbox_image = "registry.k8s.io/pause:3.10.1"
    selinux_category_range = 1024
    stats_collect_period = 10
    stream_idle_timeout = "4h0m0s"
    stream_server_address = "127.0.0.1"
```

Then restart containerd to apply the changes made by running:
```bash
sudo systemctl restart containerd.service
```

Then verify the containerd service is running correctly with the following command:
```bash
sudo systemctl status containerd.service
```

The output should show containerd as active (running).

If the containerd service was not running, run the command below:
```bash
sudo systemctl start containerd
```

To get containerd to AutoStart upon system startup with the following command:
```bash
sudo systemctl enable containerd
```

---

## Step 6: Install the Components of Kubernetes | ALL NODES

### Part A: Install Prerequisites

To begin, we need to install all prerequisite packages on all nodes by running:
```bash
sudo apt-get install curl ca-certificates apt-transport-https -y
```

**Note:** As of now, we are on version 1.34 but this may change depending on when you read this documentation, so make sure to check the latest version and change the next few commands accordingly.

To add the Kubernetes GPG signing key, run:
```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

Then, add the Kubernetes repository on the machine by running:
```bash
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

After that, update the system's source list so it recognizes the new repo by running:
```bash
sudo apt update
```

### Part B: Install Kubernetes Components

To install Kubernetes, we need 3 packages:
- kubeadm
- kubelet
- kubectl

To install all 3 components, run the command:
```bash
sudo apt install kubelet kubeadm kubectl -y
```

---

## Step 7: Initialize the Kubernetes Cluster | MASTER NODE ONLY

### Part A: Initialize Master Node

We need to initialize the master node as the control plane and make a unique pod network for the cluster by running:
```bash
sudo kubeadm init --pod-network-cidr=10.125.0.0/16
```

After the initialization completes, you will see output similar to:
```
[init] Using Kubernetes version: v1.34.2
[preflight] Running pre-flight checks
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet
[preflight] You can also perform this action beforehand using 'kubeadm config images pull'
```

At the end, you'll see:
```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.1.211:6443 --token fypukf.hjr0dlo9y8qqovuy \
  --discovery-token-ca-cert-hash sha256:aaa410fc712e4086810fe4d69c54dc0aa392d6a8033f3e3e615ea4f19e29aee1
```

Run the first command to create a `.kube` directory in the home directory:
```bash
mkdir -p $HOME/.kube
```

Run the second command to copy the cluster's config file into the `.kube` directory:
```bash
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
```

Run the third command to configure ownership of the copied config file so the user is allowed to use the config file to manage the cluster:
```bash
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Part B: Install Calico Network Plugin

We need to now install the Calico service to secure communication between pods and external services. We can auto-assign IPs to pods for smooth communication.

**Note:** As of now, we are on version 3.31.0 but this may change depending on when you read this documentation, so make sure to check the latest version and change the commands accordingly.

Run the following command to deploy the Calico operator:
```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.0/manifests/tigera-operator.yaml
```

Output:
```
namespace/tigera-operator created
serviceaccount/tigera-operator created
clusterrole.rbac.authorization.k8s.io/tigera-operator-secrets created
clusterrole.rbac.authorization.k8s.io/tigera-operator created
clusterrolebinding.rbac.authorization.k8s.io/tigera-operator-secrets created
rolebinding.rbac.authorization.k8s.io/tigera-operator-secrets created
deployment.apps/tigera-operator created
```

Then download Calico's custom-resources files by running:
```bash
curl https://raw.githubusercontent.com/projectcalico/calico/v3.31.0/manifests/custom-resources.yaml -O
```

### Part C: Update Calico's Config to Match the Pod Network

Now if you run `ls` in the home directory, you will see the `custom-resources.yaml` file.

We need to update the CIDR defined in this YAML file to match the pod's network by running:
```bash
sed -i 's/cidr: 192\.168\.0\.0\/16/cidr: 10.125.0.0\/16/g' custom-resources.yaml
```

Then run the command:
```bash
kubectl create -f custom-resources.yaml
```

---

## Step 8: Add Worker Nodes to the Cluster | ALL NODES

### Part A: Check Current Nodes

As of right now, the master node is the only node in the cluster. We can see this by running:
```bash
kubectl get nodes
```

This will show:
```
NAME              STATUS    ROLES           AGE     VERSION
k8s-master-node   NotReady  control-plane   9m51s   v1.34.2
```

### Part B: Generate Join Command

On the **MASTER NODE**, run the following command to generate the command needed for our worker nodes to join the cluster:
```bash
sudo kubeadm token create --print-join-command
```

The output will look like:
```
kubeadm join 192.168.1.211:6443 --token 7g6dcb.2irbbghurkcit7w --discovery-token-ca-cert-hash sha256:aaa410fc712e4086810fe4d69c54dc0aa392d6a8033f3e3e615ea4f19e29aee1
```

### Part C: Join Worker Nodes

Then on **ALL THE WORKER NODES**, run the command given from the output above:
```bash
sudo kubeadm join 192.168.1.211:6443 --token 7g6dcb.2irbbghurkcit7w --discovery-token-ca-cert-hash sha256:aaa410fc712e4086810fe4d69c54dc0aa392d6a8033f3e3e615ea4f19e29aee1
```

The output should look like:
```
[sudo] password for blueteam:
[preflight] Running pre-flight checks
[preflight] Reading configuration from the "kubeadm-config" ConfigMap in namespace "kube-system"...
...
[preflight] Use 'kubeadm init phase upload-config kubeadm --config your-config-file' to re-upload it.
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/instance-config.yaml"
[patches] Applied patch of type "application/strategic-merge-patch+json" to target "kubeletconfiguration"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-check] Waiting for a healthy kubelet at http://127.0.0.1:10248/healthz. This can take up to 4m0s
[kubelet-check] The kubelet is healthy after 1.503100655s
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

### Part D: Verify All Nodes Joined

Now on **THE MASTER NODE**, run the command below to verify all the worker nodes have joined:
```bash
kubectl get nodes
```

The output should look similar to:
```
NAME                 STATUS   ROLES           AGE     VERSION
k8s-master-node      Ready    control-plane   15m     v1.34.2
k8s-worker-node-1    Ready    <none>          5m      v1.34.2
k8s-worker-node-2    Ready    <none>          4m      v1.34.2
k8s-worker-node-3    Ready    <none>          3m      v1.34.2
```

To check the pods in all the namespaces, run the command:
```bash
kubectl get pods -A
```

---

## Step 9: Test the Cluster with Nginx Deployment

We will now test if the cluster is functional by deploying a service. We will use nginx.

First, create a namespace to isolate the deployment. We will name it `demo-namespace` by running:
```bash
kubectl create namespace demo-namespace
```

Then we will create a deployment inside the namespace, specify the nginx image name and 2 replicas. We will call the deployment "testing-nginx". To do all this, run:
```bash
kubectl create deployment testing-nginx --image nginx --replicas 2 --namespace demo-namespace
```

To verify the deployment in the namespace, run the command:
```bash
kubectl get deployment -n demo-namespace
```

The output should show "testing-nginx":
```
NAME            READY   UP-TO-DATE   AVAILABLE   AGE
testing-nginx   2/2     2            2           30s
```

We will now expose the deployment using the NodePort service and set it up to run an application on port 80. To do this, run:
```bash
kubectl expose deployment testing-nginx -n demo-namespace --type NodePort --port 80
```

Now to list the services in the namespace, run:
```bash
kubectl get svc -n demo-namespace
```

The output should confirm NodePort running on the namespace:
```
NAME            TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
testing-nginx   NodePort   10.96.123.45    <none>        80:32153/TCP   1m
```

**Note:** This output tells us the NodePort for nginx is `32153`, which we will need later.

To test if we can actually access the web application, from any of **THE WORKER NODES**, curl the web page by running the command:
```bash
curl http://<WORKER-IP>:32153
```

The output should look similar to:
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and working.</p>
...
</body>
</html>
```

**We now have nginx running successfully on the cluster!**

---

## Summary

That's it! You now have a functioning Kubernetes cluster with:
- 1 Master Node (control plane)
- 3 Worker Nodes
- Calico network plugin
- A working nginx deployment as a test

Congratulations on setting up your Kubernetes cluster on Proxmox!