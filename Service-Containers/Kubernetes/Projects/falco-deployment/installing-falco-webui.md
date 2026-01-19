# Learning the Basics & Installing Falco Sidekick

## What is Falco Sidekick?

Falco Sidekick is an add-on to the Falco service which receives Falco's alerts and forwards them to Falco Sidekick so you can view, store, or act on them. Falco generates the events and then Sidekick takes those events and sends them to its desired destination like its designated web UI. On top of this, you can also forward Falco's alerts to external services other than its web UI such as Prometheus and send alerts to multiple destinations at the same time.

---

## Installing Falco Sidekick

### Prerequisites

**You must have a working cluster**
- If you do not, there is documentation and step-by-step instructions in the GitHub

**Helm must be installed**
- If not, just run the command:
```bash
  curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
```

**You must install and set up Falco**
- If you have not, there is documentation and step-by-step instructions in the GitHub

---

## Setting Up Falco Sidekick

### About Namespaces

We will not be creating a new namespace for Falco Sidekick. Rather, we will be placing it in the same namespace as Falco. For Falco, we used the namespace "falco". If you missed it, namespaces partition the cluster resources which allows you to organize and isolate workloads and apply specific policies to that namespace so it doesn't affect other services. After creating a namespace, you can deploy resources into it, apply your own policies such as networking policies, and have resource quotas/requirements.

### Step 1: Upgrade Falco to Enable Sidekick

To upgrade the Falco installation to enable Falco Sidekick and its Web UI, we will run:
```bash
helm upgrade --namespace falco falco falcosecurity/falco \
  --set falcosidekick.enabled=true \
  --set falcosidekick.webui.enabled=true \
  --set falcosidekick.webui.redis.storageEnabled=false
```

**Note:** We disable Redis-backed storage to keep the setup simple in the case of the CCDC.

### Step 2: Verify Pod Status

Now (after waiting 2 minutes) we will list all the pods running in the namespace "falco", showing their current status, when it was made, how many times it was restarted, and general information. This allows us to verify all of Falco Sidekick's components such as the web UI and see if they are running as they should. This helps us to troubleshoot if anything arises with the pod. To do this, run:
```bash
kubectl wait pod --for=condition=Ready --all -n falco --timeout=120s
```

Or if it's already been a minute or two since upgrading Falco, just run:
```bash
kubectl get pods -n falco
```

### Step 3: List Services

Now we will list all the services running on pods in the Falco namespace. We will display the names, types, cluster IPs, age, and more general information to help us see how the service (Falco) and its components are communicating within the cluster and identify service endpoints to access the UI. To do this, run:
```bash
kubectl get svc -n falco
```

---

## Accessing the Falco Sidekick Web UI

Because the cluster is on a private facing subnet, we need to jump through some hoops to access the web UI on our local machine. To do this we need to first establish an SSH connection to a remote host (being our Cluster Master IP) through a jump host (in our case, the SOC machine). To get to our jump host we need to port forward through pfSense. We need to do all this while also setting up the local port forward so that connections to a port on our local machine (in our case port 8084) are tunneled through the SSH connection and forwarded to a port on the destination host (in our case, the cluster on port 8084). This will allow us to securely access services running on the remote host as if they were running locally.

### Step 1: SSH Tunnel with Jump Host

To do this, first open a NEW terminal on your local machine and run:
```bash
ssh -L 8084:localhost:8084 -J blueteam@192.168.1.131:5001 blueteam@10.0.5.6
```

**Breaking it down:**
- `ssh`: Just the SSH client command
- `-L 8084:localhost:8084`: To set up local port forwarding in a way that traffic is sent to port 8084 on the local machine, then is forwarded through the SSH tunnel to `localhost:8084` on the remote host (aka, the Master Node)
- `-J blueteam@192.168.1.131:5001`: This is the jump host we will use to get to the cluster. In our case, this is the pfSense IP at port 5001 which takes us to the SOC machine
- `blueteam@10.0.5.6`: This is the final destination which is the target host we are ultimately connecting to. In our case, the Master Node

**To replicate this with a different set of information (new IPs, ports, etc), follow this format:**
```bash
ssh -L <local-machine-open-port>:<localhost-of-destination>:<destination-open-port> -J <jump-host-username>@<jump-host-ip>:<jump-host-port> <destination-host-username>@<destination-host-ip>
```

### Step 2: Port Forward to Falco Sidekick Service

Now on this new terminal we have ONE more command to run before we can access the web UI. We need to create a port forward tunnel from our local machine's port to the port of the Falco Sidekick service in the Falco namespace. This will allow us to access the web UI by connecting to `localhost:8084` on our browser without needing to expose the service externally via an Ingress. To do this, run:
```bash
kubectl port-forward svc/falco-falcosidekick-ui -n falco 8084:2802 &
```

**To replicate this with a different set of information (new IPs, ports, etc), follow this format:**
```bash
kubectl port-forward svc/<service-frontend> -n <namespace-of-service> <local-port>:<service-port> &
```

### Step 3: Access the Web UI

Now on your local machine go to: **http://localhost:8084**

**Default Credentials:**
- Username: `admin`
- Password: `admin`

---

## Appendix

### What is Helm?

Helm is a package manager specifically for Kubernetes that simplifies certain processes of setting up a service such as installing, upgrading, configuring, and managing. Instead of manually creating a bunch of files for deployment, Helm bundles it all together into what it calls a "chart" and works like installing an app, similar to using Homebrew on Mac or apt on Ubuntu.

When you run the command for installing something on Helm, it renders the templates inside the chart, fills in your chosen settings (or the default ones), and sends the final manifest straight to Kubernetes. It keeps track of releases if you choose to upgrade, or even downgrade, the service in the future. It gives you a consistent deployment process for any service you install. Also, if you do decide you want to manually edit something in the YAML or config files, you can still do that.

### What is Port-Forwarding?

Port-forwarding lets you connect a port on your local machine to a port on another machine, in our case to a service inside a cluster even if that service isn't exposed externally. This is useful in private networks when you can't reach the service via Ingress or a load balancer.

When running a port-forward, the machine (in our case, the cluster) will set up a secure tunnel so that traffic sent to a local port is forwarded directly into the cluster. From your point of view, the service behaves as if it's running on your computer or laptop directly. This makes it simple to access Web UIs, dashboards, APIs, etc. without needing to expose anything on the private subnet.

### What is Falco?

Falco is a threat detection tool that monitors system calls on the cluster to look out for suspicious behavior. It's able to detect and alert you on potential security threats in real-time, like for example file extraction, privilege escalation, or any rootkit installs.

---

