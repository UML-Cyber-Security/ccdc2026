# Learning the Basics & Installing Falco

## What is Falco?

Falco is a threat detection tool that monitors system calls on the cluster to look out for suspicious behavior. It's able to detect and alert you on potential security threats in real-time, like for example file extraction, privilege escalation, or any rootkit installs. These malicious behaviors are detected using Falco Rules that are responsible for classifying events as malicious or suspicious.

Falco collects event data and compares each event against a set of defined rules. Some examples of sources for Falco events are:

- Linux kernel syscalls
- Kubernetes audit logs
- Cloud events (e.g., AWS CloudTrail)
- Events from other systems (e.g., GitHub)
- New data sources can be added to Falco by developing plugins

It comes pre-loaded with a large set of rules, but on the other end you can also set your own rules to customize it. So if Falco doesn't have a rule you want, just make it yourself.

---

## Installing Falco

### Prerequisites

**You must have a working cluster**
- If you do not, there is documentation and step-by-step instructions in the GitHub

**Helm must be installed**
- If not, just run the command:
```bash
  curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
```

---

## Setting Up Falco

### Step 1: Add Helm Chart Repository

Now we need to add a new Helm chart repository and we will name it "falcosecurity". This chart will be pointing to the URL `https://falcosecurity.github.io/charts` and it will store the repository name ("falcosecurity") and URL in Helm's local repository list. To do this, run:
```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
```

### Step 2: Update Helm Repositories

Now we will update the local cache of charts from all configured Helm chart repositories. Run:
```bash
helm repo update
```

### Step 3: Create Falco Namespace

Now we must create a new namespace resource and add it to the cluster, and we will name it `falco`. Namespaces partition the cluster resources which allows you to organize and isolate workloads and apply specific policies to that namespace so it doesn't affect other services. After creating a namespace, you can deploy resources into it, apply your own policies such as networking policies, and have resource quotas/requirements. To create this namespace, run:
```bash
kubectl create namespace falco
```

**Note:** I would like to note that namespaces are arbitrary.

### Step 4: Install Falco Helm Chart

Now we need to install the Falco Helm chart into the cluster with Falco's release name. What will happen is that Helm will retrieve the chart of the configured repository, render all the manifests with their default values (unless you set custom values) and will deploy all these resources into the Falco namespace and then create a Helm release record to track the entire installation. To do all this, run:
```bash
helm install falco falcosecurity/falco -n falco
```

**Breaking it down:**
- `helm install`: The Helm command to deploy the release
- `falco`: The release name assigned to the installation
- `falcosecurity/falco`: The chart reference format, aka `<repo name>/<chart name>`
- `-n falco`: Specifies the namespace where all resources are deployed

### Step 5: Verify Pod Status

Now (after waiting 2 minutes) we will list all the pods running in the namespace "falco", showing their current status, when it was made, how many times it was restarted, and general information. This allows us to verify that all of Falco's components are running as they should and it helps us to troubleshoot if anything arises with the pod. To do this, run:
```bash
kubectl wait pod --for=condition=Ready --all -n falco --timeout=120s
```

Or if it's already been a minute or two since installing the Falco Helm Chart, just run:
```bash
kubectl get pods -n falco
```

**Breaking it down:**
- `kubectl`: The command-line tool used to interact with the cluster
- `get pods`: Retrieves all pods
- `-n falco`: Specifies to get pods from only this namespace

### Step 6: List Services

Now we will list all the services running on pods in the Falco namespace. We will display the names, types, cluster IPs, age, and more general information to help us see how the service (Falco) and its components are communicating within the cluster and identify service endpoints to access the UI. To do this, run:
```bash
kubectl get svc -n falco
```

---

## Next Steps

Now I would recommend going over and reading the documentation on installing **Falco Sidekick** for a web UI.

---

## Appendix

### What is Helm?

Helm is a package manager specifically for Kubernetes that simplifies certain processes of setting up a service such as installing, upgrading, configuring, and managing. Instead of manually creating a bunch of files for deployment, Helm bundles it all together into what it calls a "chart" and works like installing an app, similar to using Homebrew on Mac or apt on Ubuntu.

When you run the command for installing something on Helm, it renders the templates inside the chart, fills in your chosen settings (or the default ones), and sends the final manifest straight to Kubernetes. It keeps track of releases if you choose to upgrade, or even downgrade, the service in the future. It gives you a consistent deployment process for any service you install. Also, if you do decide you want to manually edit something in the YAML or config files, you can still do that.

### What is Falco Sidekick?

Falco Sidekick is an add-on to the Falco service which receives Falco's alerts and forwards them to Falco Sidekick so you can view, store, or act on them. Falco generates the events and then Sidekick takes those events and sends them to its desired destination like its designated web UI.

---
