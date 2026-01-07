This isnt finished, I just put this as a placeholder

```yaml
blueteam@ccdc2-linux-k8s-master:~$ cat traefik-values-infra2.yaml
api:
  dashboard: true
  insecure: true

deployment:
  kind: DaemonSet

ingressRoute:
  dashboard:
    enabled: true
    entryPoints:
      - web
    matchRule: Host(`traefik.udoz.com`) && (PathPrefix(`/api`) || PathPrefix(`/dashboard`))

ping:
  enabled: true

ports:
  ssh:
    expose:
      default: true
    nodePort: 32222
    port: 2222
    protocol: TCP

  traefik:
    expose:
      default: true
    port: 9000

  web:
    expose:
      default: true
    nodePort: 30080
    port: 8080

  websecure:
    expose:
      default: true
    nodePort: 30443
    port: 8443

providers:
  kubernetesCRD:
    enabled: true
  kubernetesGateway:
    enabled: false
  kubernetesIngress:
    enabled: true

```