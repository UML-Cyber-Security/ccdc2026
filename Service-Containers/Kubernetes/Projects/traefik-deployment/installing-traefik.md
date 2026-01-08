# Learning the Basics & Installing Traefik

## What is Traefik?

Traefik Ingress provider is a Kubernetes ingress controller and a modern reverse proxy designed for microservices (and cloud-native applications). It manages access to the cluster's services and watches for incoming ingress events. Traefik acts as an entry point to route incoming HTTP or HTTPS traffic to the appropriate services based on its set of rules. Traefik automatically discovers services within the cluster and configures routing without manual intervention, making it easier to expose its services to you. This way you only need to worry about configuration from the services side, not Traefik's.

Traefik also handles other networking tasks such as load balancing, TLS, host-based and path-based routing. It monitors the cluster's services, pods and resources to update its configuration whenever something is modified. 

To summarize, its features include but are not limited to:

- Automatic service discovery
- Built-in SSL/TLS certification
- Multiple protocol support beyond HTTP(S) such as TCP and UDP
- Web dashboard for monitoring

---

## Installing Traefik

### Prerequisites

**You must have a working cluster**
- If you do not, there is documentation and step-by-step instructions in the GitHub

**Helm must be installed**
- If not, just run the command:
```bash
  curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
```

---

## Setting Up Traefik

### Step 1: Add Helm Chart Repository

Now we need to add a new Helm chart repository and we will name it "traefik". This chart will be pointing to the URL `https://traefik.github.io/charts` and it will store the repository name ("traefik") and URL in Helm's local repository list. To do this, run:
```bash
helm repo add traefik https://traefik.github.io/charts
```

### Step 2: Update Helm Repositories

Now we will update the local cache of charts from all configured Helm chart repositories. Run:
```bash
helm repo update
```

### Step 3: Create Traefik Namespace

Now we must create a new namespace resource and add it to the cluster, and we will name it `traefik`. Namespaces partition the cluster resources which allows you to organize and isolate workloads and apply specific policies to that namespace so it doesn't affect other services. After creating a namespace, you can deploy resources into it, apply your own policies such as networking policies, and have resource quotas/requirements. To create this namespace, run:
```bash
kubectl create namespace traefik
```

**Note:** I would like to note that namespaces are arbitrary, you could name it "spongebob" if you really wanted to but that is not recommended.

### Step 4: Install Traefik Helm Chart

Now we need to install the Traefik Helm chart into the cluster with Traefik's release name. What will happen is that Helm will retrieve the chart of the configured repository, render all the manifests with their default values (unless you set custom values) and will deploy all these resources into the Traefik namespace and then create a Helm release record to track the entire installation. To do all this, run:
```bash
helm install traefik traefik/traefik -n traefik
```

**Breaking it down:**
- `helm install`: The Helm command to deploy the release
- `traefik`: The release name assigned to the installation
- `traefik/traefik`: The chart reference format, aka `<repo name>/<chart name>`
- `-n traefik`: Specifies the namespace where all resources are deployed

### Step 5: Verify Pod Status

Now (after waiting 2 minutes) we will list all the pods running in the namespace "traefik", showing their current status, when it was made, how many times it was restarted, and general information. This allows us to verify that all of the Ingress Controller's components are running as they should and it helps us to troubleshoot if anything arises with the pod. To do this, run:
```bash
kubectl wait pod --for=condition=Ready --all -n traefik --timeout=120s
```

Or if it's already been a minute or two since installing the Traefik Helm Chart, just run:
```bash
kubectl get pods -n traefik
```

**Breaking it down:**
- `kubectl`: The command-line tool used to interact with the cluster
- `get pods`: Retrieves all pods
- `-n traefik`: Specifies to get pods from only this namespace

### Step 6: List Services

Now we will list all the services running on pods in the namespace Traefik is in. We will display the names, types, cluster IPs, age, and more general information to help us see how the Ingress Controller and its components are communicating within the cluster and identify service endpoints to access the UI. To do this, run:
```bash
kubectl get svc -n traefik
```

---

## Next Steps

Now I would recommend going over and reading the documentation on a custom configuration for Traefik. It is specific to the ccdc2026 infrastructure

---

## Appendix

### What is Helm:

Helm is a package manager specifically for Kubernetes that simplifies certain processes of setting up a service such as installing, upgrading, configuring, and managing. Instead of manually creating a bunch of files for deployment, Helm bundles it all together into what it calls a "chart" and works like installing an app, similar to using Homebrew on Mac or apt on Ubuntu.

When you run the command for installing something on Helm, it renders the templates inside the chart, fills in your chosen settings (or the default ones), and sends the final manifest straight to Kubernetes. It keeps track of releases if you choose to upgrade, or even downgrade, the service in the future. It gives you a consistent deployment process for any service you install. Also, if you do decide you want to manually edit something in the YAML or config files, you can still do that.

### What is an Ingress Provider:

An Ingress provider, aka an Ingress Controller, is the software responsible for implementing and managing traffic routing defined within the cluster's Ingress resources. The ingress resource is like a blueprint for the Ingress provider. Note: Ingress is what lets you map traffic to different backends based on rules you have defined.

### What is a Reverse Proxy:

A reverse proxy is a server that sits in front of web servers and forwards client requests to said web servers. They are implemented to increase security, performance and reliability of the service. When the web page of your service is visited, you aren't connected directly to the service server, rather you are connected to the reverse proxy which then will decide where to send your requests to based on the service's configurations. The reverse proxy handles the response from the backend and sends it back to the user of the web page.

Reverse proxies provide benefits such as load balancing across multiple servers, SSL/TLS termination, caching certain content, and very importantly hiding the internal structure of the infrastructure which helps protect services from direct internet exposure. 


### What is an SSL/TLS Certificate:

An SSL/TLS Certificate is a digital object that allows systems to verify the identity and establish an encrypted network connection to another system using the Secure Socket Layer (SSL) and Transport Security Layer (TLS) protocol. Certificates are used within a cryptographic system known as a public key infrastructure (PKI). PKI provides a way for one party to verify the identity of another party using certificates if both parties trust a third party. This is known as a certificate authority, or CA for short. SSL/TLS certificates essentially act as digital ID cards to secure network communication

When you connect to a website via HTTPS, the server will send its TLS certificate to the browser with its public key which will be digitally signed by a trusted CA. Your browser verifies the signature, confirms the certificate is valid and uses the public key to establish an encrypted connection.

In Kubernetes, Traefik or other Ingress Controllers like Nginx can automatically obtain and renew TLS certificates (when configured with a certificate resolver for an Automatic Certificate Management Environment provider). So when your services like ArgoCD or Grafana can serve encrypted traffic without needing you to manually manage certification and all the troubles that come with it. 

### What are Microservices:

Microservices is an architectural approach where you build an application or service as a collection of small independently functioning services rather than one large monolithic service. Each "microservice" focuses on one job for the main service without worrying about the others. These services run independently but still communicate with each other and can be worked on, deployed, and scaled separate from one another. 

For example, in Kubernetes microservices run as separate deployments within their own pods on the cluster. This way different microservices of the main service can use different languages, databases, etc. 

While a microservices architecture does have many benefits, it also has its own downsides. The attack surface is much larger due to how the application is split into many small parts, this requires individual security policies, authentication protocols, and networking. A single misconfiguration can cause issues for the entire cluster. Because of all this extra necessary security, setting up an application with microservices is much more daunting and complex. 

**Note: To learn some more about Traefik, there will be a document posted soon about Traefik traffic routing configuration with Gitea as the example.**

---