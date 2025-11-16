**Things to consider:**
- If you don't understand how kubernetes work, I would advise reading documentation on the theory before moving onto the implementation 
- This documentation will assume 1 master node and 3 worker nodes
**What you need before starting **
- 4 Ubuntu Server machine running with 4 gigabytes of ram and 32 gigabytes of disk space and 2 cores for the worker nodes and 4 cores for the master node

**Step 1: Configure hostnames | ALL NODES**
**Part A:**
In each of the machines modify the hostnames to something recognizable like below:
I changed the hostname of the master node to "k8s-master-node" by running the command:

**`sudo hostnamectl set-hostname "k8s-master-node"`**

I then changed the hostname of the 1st worker node to "k8s-worker-node-1" by running the command:	

**`sudo hostnamectl set-hostname "k8s-worker-node-1"`**
- Do the same for the other 2 worker nodes 

For the changes to go through run the following command on EVERY machine:

**`sudo exec bach`**

To verify the changes run the following command on EVERY machine:

**`hostname`**

**Part B:**
Update the /etc/host file and add the IP addresses and hostnames for the Master Node and worker nodes by running the following command: 

**`sudo nano /etc/hosts`** 

Once in the file change it like it is below but replace the example IP and example hostname to match the IP's and Hostnames of your machines of your machines you set in Step 1 Part A. 
![[Pasted image 20251115171113.png]]

To ensure you can communicate to all the nodes in the cluster, from each node ping every machine using their hostname by running the following command:

**`ping -c 3 k8s-worker-node-1`**

The result should imitate this:
![[Pasted image 20251115171616.png]]

**Step 2: Disable Swap space | ALL NODES**
**Part A:**
To disable swap on the nodes, run the following command:

**`sudo swapoff -a`**

To persist the change run the following command to access & change the /etc/fstab file:

**`sudo nano /etc/fstab`**

In the file comment out the '/swap.img' line as shown below:
![[Pasted image 20251115173043.png]]

To check if swap space has been disabled run the command:

**`swapon --show`**

If the output is blank, swap space has been disabled

Step 3: Load the Containerd modules | ALL NODES
Part A:
To enable and load modules run the following commands on ALL machines:

**`sudo modprobe overlay`**

**`sudo modprobe br_netfilter`**

Then create a configuration fole to specify the modules to load them permanently using the following command on ALL machines:

```
**sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF**
```

**Step 4: Configure the IPv4 Networking | ALL NODES
Part A:**
Create a K8 configuration file in the /etc/sysctl.d/ directory with the following command and then add the following lines after:

**`sudo nano /etc/sysctl.d/k8s.conf`**

Then add these lines in the k8s.conf file:

```
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward   = 1
```

Apply these settings by running the following command:

**`sudo sysctl --system`**

Step 5: Installing Docker | ALL NODES
Part A:
To install docker from Ubuntu's default repos, run these command on ALL machines:

```
sudo apt update
sudo apt install docker.io -y
```

To verify if docker is running, run the following command on ALL machines:

**`sudo systemctl status docker`**

The output should look like this:
![[Pasted image 20251115183711.png]]

If docker is not active run the following command:

**`sudo systemctl start docker`**

Also, enable the Docker daemon for AutoStart upon system startup with the following command:

**`sudo systemctl enable docker`**

**Part B:**
Now we need to configure containerd. We begin this by first creating the /etc/containerd directory by running the following command:

**`sudo mkdir /etc/containerd`**

Then create the default config file for containerd by running:

**`sudo sh -c "containerd config default > /etc/containerd/config.toml"`**

Then update the SystemdCgroup directive by setting it to true with the following command:

**`sudo sed -i 's/ SystemdCgroup = false/ SystemdCgroup = true/' /etc/containerd/config.toml`**

Then restart containerd to apply the changes made by running:

**`sudo systemctl restart containerd.service`**

Then verify the containerd service is running correctly with the following command:

**`sudo systemctl status containerd.service`**

The output to look something like this:
![[Pasted image 20251115184442.png]]

If the containerd service was not running as shown above, then run the command below:

**`sudo systemctl start containerd`**

To get containerd to AutoStart upon system startup with the following command:

**`sudo systemctl enable containerd`**

**Step 6: Install the components of Kubernetes | ALL NODES
Part A:**
To begin, we ned to install all prerequisite packages on all nodes by running:

**`sudo apt-get install curl ca-certificates apt-transport-https  -y`**

**Note:**
- **that as of now, we are on version 1.34 but this may change depending on when you read this documentation so make sure to check the latest version and change the next few commands accordingly**

To add the Kubernetes GPG signing key run:

**`curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg`**

Then, add the kubernetes repository on the machine by running:

**`echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list`**

After that, update the systems source list so it recognizes he new repo by running:

**`sudo apt update`**

**Part B:**
To install kubernetes we need 3 packages: 
- kubeadm
- kubelet
- kubectl
To install all 3 components run the command:

**`sudo apt install kubelet kubeadm kubectl -y`**

**Step 7: Initialize the Kubernetes cluster | ON JUST MASTER NODE
Part A:**
We need to initialize the master node as the control plan and make a unique pod network for the cluster by running:

**`sudo kubeadm init --pod-network-cidr=10.125.0.0/16`**

After that is complete you will be given 3 commands to run in your output as shown below:
![[Pasted image 20251115190333.png]]

Run the first command to create a .kube directory in the home directory:

**`mkdir -p $HOME/.kube`**

Run the second command to copy the clusters config file into the .kube directory:

**`sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config`**

Run the third command to configure ownership of the copied config file so the user is allowed to use the config file to manage the cluster:

**`sudo chown $(id -u):$(id -g) $HOME/.kube/config`**

**Part B:**
We need to now install the Calico service to secure communication between pods and external services. We can auto-assign IP's to pods for smooth communication
**Note:**
- **that as of now, we are on version 3.31.0 but this may change depending on when you read this documentation so make sure to check the latest version and change the commands accordingly**

Run the following command to deploy the Calico operator:

**`kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.0/manifests/tigera-operator.yaml`**

Then download Calicos custom-resources files by running:

**`curl https://raw.githubusercontent.com/projectcalico/calico/v3.31.0/manifests/custom-resources.yaml -O`**

Part C: Update calicos config to match the pod network
Now if you run 'ls' in the home directory you will see:
![[Pasted image 20251115191008.png]]

We need to update the CIDR defined in this yaml file to match the pods network by running:

**`sed -i 's/cidr: 192\.168\.0\.0\/16/cidr: 10.125.0.0\/16/g' custom-resources.yaml`**

Then run the command:

**`kubectl create -f custom-resources.yaml`**

**Part 8 | ALL NODES**
**Part A:**
As of right now, the master node is the only node in the cluster, we can see this by running:

**`kubectl get nodes`**

This will show us:
![[Pasted image 20251115191316.png]]
We need to add the rest of the nodes on the cluster. 

On the **MASTER NODE** run the following command to generate the command needed for our worker nodes to join the cluster:

**`sudo kubeadm token create --print-join-command`**

The output will look like:
![[Pasted image 20251115191928.png]]

Then on **ALL THE WORKER NODES** run the command given from the output above

**`kubeadm join 192.168.1.211:6443 --token 79gdcbl.2irbbghkurckcit7w --discovery-token-ca-cert-hash sha256:aaa410fc712e4086810fef4d69c54dc0aa392d6a8033f3e3e615ea4f19e29aee1`**

The output should look like below: ![[Pasted image 20251115191943.png]]

Now on **THE MASTER NODE** run the command below to verify all the worker nodes have joined:

**`kubectl get nodes`**

The output should look similar to the example below:
![[Pasted image 20251115192258.png]]

To check the pods in all the namespaces run the command:

**`kubectl get pods -A`**

**Step 9**
**Part A:**
We will now test if the cluster is functional by deploying a service, we will go with nginx

In the **MASTER NODE** create a namespace to isolate the deployment, we will name it demo-namespace by running:

**`kubectl create namespace demo-namespace`**

Then we will create a deployment inside the namespace, specify the nginx image name and 2 replicates. We will call the deployment "testing-nginx". To do all this run:

**`kubectl create deployment testing-nginx --image nginx --replicas 2 --namespace demo-namespace`**

To verify the deployment in the namespace run the command:

**`kubectl get deployment -n demo-namespace`**

The output should show "testing-nginx" as shown below:
![[Pasted image 20251115192919.png]]

We will now expose the deployment using the NodePort service and set it up to run an application on port 80 for this example. To do this run:

**`kubectl expose deployment testing-nginx -n demo-namespace --type NodePort --port 80`**

Now to list the services in the namespace run:

**`kubectl get svc -n demo-namespace`**

The output should confirm NodePort running on the namespace as shown in the example below:
![[Pasted image 20251115193117.png]]
**Note this output tells us the node-port IP for nginx is 32153 which we will need later**

To test if we can actually access the web-application, from any of **THE WORKER NODES** curl the web page by running the command:

**`curl http://<WORKER-IP>:<NODE PORT>`**

The output should look similar to below:
![[Pasted image 20251115193407.png]]
***We now have nginx running successfully on the cluster!!
Thats it, thats a functioning k8 cluster right there.***
