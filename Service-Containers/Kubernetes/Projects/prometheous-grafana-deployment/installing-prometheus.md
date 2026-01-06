# Learning the Basics & Installing Prometheus

## What is Prometheus?

Prometheus is an open-source and free systems monitoring and alerting toolkit that discovers everything running in the cluster and collects detailed metrics such as resource usage and cluster health. It runs a database that stores numeric data scraped from various places such as all the nodes, their pods, application endpoints, etc. You can stack Prometheus with other tools such as Grafana to visualize the data with dashboards, which will be covered in a separate document.

## What Features Come with Prometheus?

- Multi-dimensional data model with time series data
- Uses PersistentVolumeClaim to store long-term metric data
- PromQL, a query language
- No reliance on distributed storage
- Targets discovered via service discovery or static configuration
- Multiple modes of graphing and dashboarding support

---

## Installing Prometheus

### Prerequisites

**You must have a working cluster**
- If you do not, there is documentation and step-by-step instructions in the GitHub

**Helm must be installed**
- If not, just run the command:
```bash
  curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
```

**Install and set up Longhorn**
- If you have not, there is documentation and step-by-step instructions in the GitHub

---

## Setting Up Prometheus

### Step 1: Add Helm Chart Repository

Now we need to add a new Helm chart repository and we will name it "prometheus-community". This chart will be pointing to the URL `https://prometheus-community.github.io/helm-charts` and it will store the repository name ("prometheus-community") and URL in Helm's local repository list. To do this, run:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
```

### Step 2: Update Helm Repositories

Now we will update the local cache of charts from all configured Helm chart repositories. Run:
```bash
helm repo update
```

### Step 3: Create Monitoring Namespace

Now we must create a new namespace resource and add it to the cluster, and we will name it `monitoring`. Namespaces partition the cluster resources which allows you to organize and isolate workloads and apply specific policies to that namespace so it doesn't affect other services. After creating a namespace, you can deploy resources into it, apply your own policies such as networking policies, and have resource quotas/requirements. To create this namespace, run:
```bash
kubectl create namespace monitoring
```

**Note:** I would like to note that namespaces are arbitrary.

### Step 4: Install Prometheus Helm Chart

Now we need to install the Prometheus Helm chart into the cluster with the Prometheus release name. What will happen is that Helm will retrieve the chart of the configured repository, render all the manifests with our custom values (or default values if you do nothing extra) and will deploy all these resources into the monitoring namespace and then create a Helm release record to track the entire installation. To do all this, run:
```bash
helm install prometheus prometheus-community/prometheus -n monitoring
```

**Breaking it down:**
- `helm install`: The Helm command to deploy the release
- `prometheus`: The release name assigned to the installation
- `prometheus-community/prometheus`: The chart reference format, aka `<repo name>/<chart name>`
- `-n monitoring`: Specifies the namespace where all resources are deployed

### Step 5: Verify Pod Status

Now (after waiting 2 minutes) we will list all the pods running in the monitoring namespace, showing their current status, when it was made, how many times it was restarted, and general information. This allows us to verify that all monitoring components are running as they should and it helps us to troubleshoot if anything arises with the pod. To do this, run:
```bash
kubectl wait pod --for=condition=Ready --all -n monitoring --timeout=120s
```

Or if it's already been a minute or two since installing the Prometheus Helm Chart, just run:
```bash
kubectl get pods -n monitoring
```

**Breaking it down:**
- `kubectl`: The command-line tool used to interact with the cluster
- `get pods`: Retrieves all pods
- `-n monitoring`: Specifies to get pods from only this namespace

### Step 6: List Services

Now we will list all the services running on pods in the Prometheus namespace. We will display the names, types, cluster IPs, age, and more general information to help us see how the service (Prometheus) and its components are doing network communication within the cluster and identify service endpoints to access the UI or API. To do this, run:
```bash
kubectl get svc -n monitoring
```

---

## Accessing the Prometheus Web UI

Because the cluster is on a private facing subnet, we need to jump through some hoops to access the web UI on our local machine. To do this we need to first establish an SSH connection to a remote host (being our Cluster Master IP) through a jump host (in our case, the SOC machine). To get to our jump host we need to port forward through pfSense. We need to do all this while also setting up the local port forward so that connections to a port on our local machine (in our case port 8082) are tunneled through the SSH connection and forwarded to a port on the destination host (in our case, the cluster on port 8082). This will allow us to securely access services running on the remote host as if they were running locally.

### Step 1: SSH Tunnel with Jump Host

To do this, first open a NEW terminal on your local machine and run:
```bash
ssh -L 8082:localhost:8082 -J blueteam@192.168.1.131:5001 blueteam@10.0.5.6
```

**Breaking it down:**
- `ssh`: Just the SSH client command
- `-L 8082:localhost:8082`: To set up local port forwarding in a way that traffic is sent to port 8082 on the local machine, then is forwarded through the SSH tunnel to `localhost:8082` on the remote host (aka, the Master Node)
- `-J blueteam@192.168.1.131:5001`: This is the jump host we will use to get to the cluster. In our case, this is the pfSense IP at port 5001 which takes us to the SOC machine
- `blueteam@10.0.5.6`: This is the final destination which is the target host we are ultimately connecting to. In our case, the Master Node

**To replicate this with a different set of information (new IPs, ports, etc), follow this format:**
```bash
ssh -L <local-machine-open-port>:<localhost-of-destination>:<destination-open-port> -J <jump-host-username>@<jump-host-ip>:<jump-host-port> <destination-host-username>@<destination-host-ip>
```

### Step 2: Port Forward to Prometheus Service

Now on this new terminal we have ONE more command to run before we can access the web UI. We need to create a port forward tunnel from our local machine's port to the port of the prometheus front-end service in the monitoring namespace. This will allow us to access the web UI by connecting to `localhost:8082` on our browser without needing to expose the service externally via an Ingress. To do this, run:
```bash
kubectl port-forward svc/prometheus-server -n monitoring 8082:80 &
```

**To replicate this with a different set of information (new IPs, ports, etc), follow this format:**
```bash
kubectl port-forward svc/<service-frontend> -n <namespace-of-service> <local-port>:<service-port> &
```

### Step 3: Access the Web UI

Now on your local machine go to: **http://localhost:8082**

There is no username/password in place.

---

## Appendix

### What is Helm?

Helm is a package manager specifically for Kubernetes that simplifies certain processes of setting up a service such as installing, upgrading, configuring, and managing. Instead of manually creating a bunch of files for deployment, Helm bundles it all together into what it calls a "chart" and works like installing an app, similar to using Homebrew on Mac or apt on Ubuntu.

When you run the command for installing something on Helm, it renders the templates inside the chart, fills in your chosen settings (or the default ones), and sends the final manifest straight to Kubernetes. It keeps track of releases if you choose to upgrade, or even downgrade, the service in the future. It gives you a consistent deployment process for any service you install. Also, if you do decide you want to manually edit something in the YAML or config files, you can still do that.

Also note that a Helm chart is the packaged set of manifests. These manifests define how to deploy the service. The chart is what is bundled with the templates, configurations, and dependencies.

### What is Port-Forwarding?

Port-forwarding lets you connect a port on your local machine to a port on another machine, in our case to a service inside a cluster even if that service isn't exposed externally. This is useful in private networks when you can't reach the service via Ingress or a load balancer.

When running a port-forward, the machine (in our case, the cluster) will set up a secure tunnel so that traffic sent to a local port is forwarded directly into the cluster. From your point of view, the service behaves as if it's running on your computer or laptop directly. This makes it simple to access Web UIs, dashboards, APIs, etc. without needing to expose anything on the private subnet.

### What is PromQL?

PromQL is the query language used by Prometheus to analyze metrics stored in its time series database. It is built for working with data that changes as time goes by such as memory usage, request rates, number of errors, etc. You can calculate averages, rates, trends and understand things with a bird's eye view. You can narrow down queries to certain nodes or pods in those nodes, namespaces or individual services. This is useful for troubleshooting a service that is failing or to check performance issues.

### What is PersistentVolumeClaim (PVC)?

PVC is how applications will request storage after a restart. It is a storage ticket that will tell how much space it needs and what kind of storage it needs, and Kubernetes will give it just that. It will work with another service such as Longhorn to create what it needs. After a PVC is made, the pod mounts it like a normal disk and any data stored in it will stay intact even if the pod is deleted or removed from the cluster.

---


You now have Prometheus installed and running on your cluster. You can access the web UI, begin monitoring your cluster's health, data and metrics, and connect prometheus to grafana (check other doc). 