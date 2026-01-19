# Learning the Basics & Installing Longhorn

## What is Longhorn?

Longhorn is a lightweight distributed block storage system for Kubernetes. Longhorn is free and open source which was originally developed by Rancher Labs, and is now being treated as an incubating project of the Cloud Native Computing Foundation.

## What Can You Do with Longhorn?

- Use volumes as persistent storage for distributed stateful applications
- Partition block storage into Longhorn volumes to use Kubernetes volumes with OR without a cloud provider like AWS
- Replicate block storage across multiple nodes
- Store backup data in external storage (like AWS S3)
- Create cross-cluster disaster recovery volumes so if something happens to the data you can quickly recover it to a second cluster
- Schedule recurring snapshots of a volume and restore these volumes from a backup

---

## Installing Longhorn

### Prerequisites

**You must have a working cluster**
- If you do not, there is documentation and step-by-step instructions in the GitHub

**You must have the open-iscsi and nfs-common packages installed**

These packages are necessary because Longhorn needs them for how they provide persistent storage. These packages contain the protocols used to expose & enable block storage volumes to pods. To install them, run:
```bash
sudo apt update
sudo apt install -y open-iscsi nfs-common
sudo systemctl enable --now iscsid
```

**After running, restart the whole cluster** (I know, pretty annoying but it's necessary)

**Helm must be installed**
- If not, just run the command:
```bash
  curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
```

---

## Setting Up Longhorn

### Step 1: Add Helm Chart Repository

Now we need to add a new Helm chart repository and we will name it "longhorn". This chart will be pointing to the URL `https://charts.longhorn.io` and it will store the repository name ("longhorn") and URL in Helm's local repository list. To do this, run:
```bash
helm repo add longhorn https://charts.longhorn.io
```

### Step 2: Update Helm Repositories

Now we will update the local cache of charts from all configured Helm chart repositories. Run:
```bash
helm repo update
```

### Step 3: Create Longhorn Namespace

Now we must create a new namespace resource and add it to the cluster, and we will name it `longhorn`. Namespaces partition the cluster resources which allows you to organize and isolate workloads and apply specific policies to that namespace so it doesn't affect other services. After creating a namespace, you can deploy resources into it, apply your own policies such as networking policies, and have resource quotas/requirements. To create this namespace, run:
```bash
kubectl create namespace longhorn
```

### Step 4: Install Longhorn Helm Chart

Now we need to install the Longhorn Helm chart into the cluster with the Longhorn release name. What will happen is that Helm will retrieve the chart of the configured repository, render all the manifests with their default values (unless you set custom values) and will deploy all these resources into the Longhorn namespace and then create a Helm release record to track the entire installation. To do all this, run:
```bash
helm install longhorn longhorn/longhorn -n longhorn
```

**Breaking it down:**
- `helm install`: The Helm command to deploy the release
- `longhorn`: The release name assigned to the installation
- `longhorn/longhorn`: The chart reference format, aka `<repo name>/<chart name>`
- `-n longhorn`: Specifies the namespace where all resources are deployed

### Step 5: Verify Pod Status

Now (after waiting 2 minutes) we will list all the pods running in the Longhorn namespace, showing their current status, when it was made, how many times it was restarted, and general information. This allows us to verify that all Longhorn components are running as they should and it helps us to troubleshoot if anything arises with the pod. To do this, run:
```bash
kubectl wait pod --for=condition=Ready --all -n longhorn --timeout=120s
```

Or if it's already been a minute or two since installing the Longhorn Helm Chart, just run:
```bash
kubectl get pods -n longhorn
```

**Breaking it down:**
- `kubectl`: The command-line tool used to interact with the cluster
- `get pods`: Retrieves all pods
- `-n longhorn`: Specifies to get pods from only this namespace

### Step 6: List Services

Now we will list all the services running on pods in the Longhorn namespace. We will display the names, types, cluster IPs, age, and more general information to help us see how the service (Longhorn) and its components are doing network communication within the cluster and identify service endpoints to access the UI or API. To do this, run:
```bash
kubectl get svc -n longhorn
```

---

## Accessing the Longhorn Web UI

Because the cluster is on a private facing subnet, we need to jump through some hoops to access the web UI on our local machine. To do this we need to first establish an SSH connection to a remote host (being our Cluster Master IP) through a jump host (in our case, the SOC machine). To get to our jump host we need to port forward through pfSense. We need to do all this while also setting up the local port forward so that connections to a port on our local machine (in our case port 8081) are tunneled through the SSH connection and forwarded to a port on the destination host (in our case, the cluster on port 8081). This will allow us to securely access services running on the remote host as if they were running locally.

### Step 1: SSH Tunnel with Jump Host

To do this, first open a NEW terminal on your local machine and run:
```bash
ssh -L 8081:localhost:8081 -J blueteam@192.168.1.131:5001 blueteam@10.0.5.6
```

**Breaking it down:**
- `ssh`: Just the SSH client command
- `-L 8081:localhost:8081`: To set up local port forwarding in a way that traffic is sent to port 8081 on the local machine, then is forwarded through the SSH tunnel to `localhost:8081` on the remote host (aka, the Master Node)
- `-J blueteam@192.168.1.131:5001`: This is the jump host we will use to get to the cluster. In our case, this is the pfSense IP at port 5001 which takes us to the SOC machine
- `blueteam@10.0.5.6`: This is the final destination which is the target host we are ultimately connecting to. In our case, the Master Node

**To replicate this with a different set of information (new IPs, ports, etc), follow this format:**
```bash
ssh -L <local-machine-open-port>:<localhost-of-destination>:<destination-open-port> -J <jump-host-username>@<jump-host-ip>:<jump-host-port> <destination-host-username>@<destination-host-ip>
```

### Step 2: Port Forward to Longhorn Service

Now on this new terminal we have ONE more command to run before we can access the web UI. We need to create a port forward tunnel from our local machine's port to port 80 of the longhorn-frontend service in the Longhorn namespace. This will allow us to access the web UI by connecting to `localhost:8081` on our browser without needing to expose the service externally via an Ingress. To do this, run:
```bash
kubectl port-forward svc/longhorn-frontend -n longhorn 8081:80 &
```

**To replicate this with a different set of information (new IPs, ports, etc), follow this format:**
```bash
kubectl port-forward svc/<service-frontend> -n <namespace-of-service> <local-port>:<service-port> &
```

### Step 3: Access the Web UI

Now on your local machine go to: **http://localhost:8081**

There is no username/password in place.

---

## Appendix

### What is a Block Storage System?

A block storage system is a way of storing data in which the device is divided into (fixed) chunks called blocks. The system reads and writes those blocks directly. Each block has its own address and the Kubernetes system will treat the storage as if it's just raw disk space.

The benefit of this is that it's fast and efficient for a database that needs low latency reading and writing. With regular storage you have to deal with objects and metadata, but because of the structure of block storage, or the lack thereof, this isn't an issue, providing you with a high performing virtual disk.

### What is a Distributed Stateful Application?

A distributed stateful application is a program that stores data and keeps track of that data over time. The stateful application can run across multiple nodes and isn't tied to one, which is especially useful for Kubernetes (not useful, actually necessary). The idea is that this is for an application whose pods need persistent storage and needs to keep their data even if the container restarts or moves to a new node/machine.

Applications such as Longhorn are "distributed stateful applications" because they maintain critical data that CANNOT be lost. Without a storage layer like Longhorn, running stateful applications across a cluster becomes a big pain since each node's data on their disk would be isolated.

### What is Port-Forwarding?

Port-forwarding lets you connect a port on your local machine to a port on another machine, in our case to a service inside a cluster even if that service isn't exposed externally. This is useful in private networks when you can't reach the service via Ingress or a load balancer.

When running a port-forward, the machine (in our case, the cluster) will set up a secure tunnel so that traffic sent to a local port is forwarded directly into the cluster. From your point of view, the service behaves as if it's running on your computer or laptop directly. This makes it simple to access Web UIs, dashboards, APIs, etc. without needing to expose anything on the private subnet.

### What is Helm?

Helm is a package manager specifically for Kubernetes that simplifies certain processes of setting up a service such as installing, upgrading, configuring, and managing. Instead of manually creating a bunch of files for deployment, Helm bundles it all together into what it calls a "chart" and works like installing an app, similar to using Homebrew on Mac or apt on Ubuntu.

When you run the command for installing something on Helm, it renders the templates inside the chart, fills in your chosen settings (or the default ones), and sends the final manifest straight to Kubernetes. It keeps track of releases if you choose to upgrade, or even downgrade, the service in the future. It gives you a consistent deployment process for any service you install. Also, if you do decide you want to manually edit something in the YAML or config files, you can still do that.

---

