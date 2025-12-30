# YAML with Kubernetes

## Introduction

Kubernetes uses YAML to create objects like pods, services, or deployments.

## Basic Fields of a Kubernetes Definition File

The root level properties:

- **apiVersion**: Version of the Kubernetes API used to create the object
- **kind**: Type of object you are trying to create (e.g., Pod, Service, Deployment, etc.)
- **metadata**: A dictionary about the data of the object, like the name, labels, etc.
- **spec**: Where you provide more information about the object, which is going to be different in different scenarios

---

## Example: Basic YAML Structure

Here is an example with a basic YAML file structure:
```yaml
apiVersion:
kind:
metadata:


spec:
```

---

## Example: Complete Pod Definition

Here is an example with a full YAML file:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp-pod
  labels:
    app: myapp
    type: front-end
spec:
  containers:
  - name: nginx-container
    image: nginx
```

---

## Working with YAML Files

### Apply Changes

If you wanted to actually apply the changes, you would run the command:
```bash
kubectl create -f file-name.yaml
```

### View Pods

To see the pod, run the command:
```bash
kubectl get pods
```

### Describe a Specific Pod

To get some information about the pod, run the command:
```bash
kubectl describe pod myapp-pod
```

### Describe All Pods in a Namespace

To get information about all the pods in a namespace, run:
```bash
kubectl describe pods -n <name-of-namespace>
```

---
