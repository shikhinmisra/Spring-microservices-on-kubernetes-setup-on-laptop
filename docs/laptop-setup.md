# Laptop setup notes & troubleshooting

Machine: Windows x64, Docker Desktop with built-in Kubernetes.

## Changes from the original course repo
| Problem | Fix in this repo |
|---|---|
| Course images on Docker Hub (`saiupadhyayula007/*`) are **arm64-only** → `CrashLoopBackOff` (exec format error) on x86 | Images are built locally with `services/Dockerfile` and pushed to Harbor |
| Root `pom.xml` had `<dockerPassword>${dockerPassword}</dockerPassword>` (recursive property) → Maven refuses to build | Removed, together with the arm64 `dashaun/builder:tiny` / Docker Hub publish config |
| `avro-maven-plugin` had no version in notification-service → Maven picks 1.12, generated code needs `JsonSchemaParser` missing from avro 1.11.3 | Plugin pinned to 1.11.3 |
| README referenced `infrastructure.yaml` / `applications.yaml` and `svc/gateway-service` | Kustomize folders; gateway service is `api-gateway` |
| `kafka-mysql.yml` actually contains Keycloak's MySQL | Renamed `keycloak-mysql.yml` |

## Docker Desktop specifics
- **Use the Kubeadm cluster type.** The kind type keeps its own image store and doesn't forward NodePorts the same way.
- Harbor's `localhost:30002`: the NodePort works *inside* the Docker VM (docker push, kubelet pulls), but Windows only
  sees **LoadBalancer** services on localhost — so `install-harbor.ps1` patches the Harbor service to LoadBalancer on 30002.
- Docker treats `localhost:*` registries as insecure (HTTP) automatically; no `daemon.json` change needed.

## Resource limits
The full stack (Kafka, ZooKeeper, Schema Registry, 2× MySQL, MongoDB, Keycloak, Prometheus, Grafana, Loki, Tempo,
6 apps) plus Harbor needs roughly 8–10 GB. Symptom of running out: `kubectl` → `TLS handshake timeout`, Docker Desktop
UI freezing. Fix: restart Docker Desktop, remove unrelated workloads, and raise the WSL2 limit:
```
# %UserProfile%\.wslconfig
[wsl2]
memory=10GB
processors=4
```
then `wsl --shutdown` and start Docker Desktop again.

## Useful commands
```
kubectl get pods -o wide
kubectl describe pod <pod>                # Events at the bottom explain Pending / ImagePullBackOff
kubectl logs deploy/<name> --previous     # why a container crashed
kubectl -n harbor get pods,svc
```
