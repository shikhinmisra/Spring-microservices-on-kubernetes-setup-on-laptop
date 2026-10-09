---
name: deploy-local
description: Deploy or start the stack on the laptop's Docker Desktop Kubernetes safely - memory check, core infrastructure, backend services, health verification and port-forward links. Use when the user asks to deploy, start, bring up, or run the project locally.
argument-hint: "[full]"
---

# Deploy locally $ARGUMENTS

1. **Preflight**
   - `kubectl config current-context` must be `docker-desktop`; `kubectl get nodes` node `docker-desktop` (kubeadm). If the API
     times out (`TLS handshake timeout`), stop and use the `troubleshoot-cluster` skill.
   - Memory: `wsl -d docker-desktop free -m` (Windows) or `docker stats --no-stream`. Record the "available" MB.
   - Harbor up: `curl -s http://localhost:30002/api/v2.0/ping` returns `Pong`. If not, run `scripts/windows/install-harbor.ps1`.
2. **Decide scope**
   - Default = backend only: `k8s/infrastructure/core` + `k8s/apps/overlays/local`.
   - `full` ($ARGUMENTS) only if the user asked AND available memory > 4 GB after core is running. Otherwise refuse and explain.
3. **Apply** (render first, never `-f` on a folder):
   ```
   kubectl kustomize k8s/infrastructure/core > /dev/null && kubectl apply -k k8s/infrastructure/core
   kubectl wait --for=condition=available deploy/mysql deploy/mongodb deploy/broker deploy/schema-registry --timeout=600s
   kubectl apply -k k8s/apps/overlays/local          # or overlays/full + infrastructure/extras when allowed
   kubectl rollout status deploy/product-service deploy/order-service deploy/inventory-service --timeout=300s
   ```
   Windows shortcut: `scripts\windows\deploy.ps1` (`-Full` for everything).
4. **Verify**: all pods Running/Ready, no restarts climbing (`kubectl get pods`). Check memory again; if available < 2 GB,
   scale down anything not in the default set (allowed without asking) and tell the user.
5. **Hand over** the links (each port-forward in its own window):
   product http://localhost:8080/swagger-ui.html, order :8081, inventory :8082, Harbor http://localhost:30002.
   In-stock SKUs: iphone_15, pixel_8, galaxy_24, oneplus_12.
