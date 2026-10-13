# Build-from-scratch checklist

The order to rebuild this project from an empty laptop. Each phase depends on the ones above it.
⛔ marks a gate from `CLAUDE.md`. Do not continue until it passes.

**Critical path:** 0 → 1 → 2 (product → inventory → order → notification → gateway) → 4 → 5 → 6 → 7 → 8.
Phases 3, 10 and 11 can run in parallel with the others.

---

## 0. Laptop prerequisites
- [ ] Install JDK 21, Maven 3.9+, Node 20 + Angular CLI, Git, Helm, kubectl
- [ ] Install Docker Desktop (WSL2 backend)
  - [ ] Settings → Resources: VM about 8 GB RAM (16 GB laptop)
  - [ ] Settings → Kubernetes: enable, cluster type = **kubeadm**
- [ ] `kubectl config use-context docker-desktop`; `kubectl get nodes` → Ready

## 1. Repository skeleton
- [ ] `git init`; `.gitignore`, `.dockerignore`, `README.md`
- [ ] Root parent `pom.xml`: Spring Boot 3.2, Java 21, dependencyManagement, Testcontainers BOM, modules = `services/*`
- [ ] Folders: `services/`, `k8s/`, `argocd/`, `scripts/windows/`, `local-dev/`, `docs/`

## 2. Microservices (one Maven module each, test-first)
- [ ] **product-service** (:8080, MongoDB)
  - [ ] model / repository / service / controller (CRUD `/api/product`)
  - [ ] `@SpringBootTest` + Testcontainers MongoDB
- [ ] **inventory-service** (:8082, MySQL + Flyway)
  - [ ] `db/migration/V1__init.sql`, `V2__add_inventory.sql`
  - [ ] `GET /api/inventory?skuCode&quantity` → boolean
  - [ ] `@SpringBootTest` + Testcontainers MySQL
- [ ] **order-service** (:8081, MySQL + Kafka/Avro, calls inventory)
  - [ ] Flyway `V1__init.sql`; `avro/order-placed.avsc` (avro-maven-plugin)
  - [ ] Inventory client (RestClient) + Resilience4j circuit breaker / retry
  - [ ] Publish `OrderPlacedEvent` to Kafka (Schema Registry)
  - [ ] Tests: Testcontainers MySQL + Kafka, WireMock for inventory
- [ ] **notification-service** (:8083, Kafka consumer → mail)
  - [ ] Same `order-placed.avsc`
  - [ ] Test: Testcontainers Kafka
- [ ] **api-gateway** (:9000, Spring Cloud Gateway MVC + Keycloak OAuth2 resource server)
  - [ ] Routes to product / order / inventory, aggregated Swagger docs
- [ ] **frontend** (Angular + Tailwind, OIDC login, product/order pages)
- [ ] All services: actuator health + prometheus, `logback-spring.xml` (Loki), tracing
- [ ] ⛔ `mvn -pl services/<svc> -am verify` passes for every service

## 3. Local dev without Kubernetes (optional)
- [ ] `local-dev/docker-compose.yml`
- [ ] `local-dev/docker/`: `mysql/init.sql`, Keycloak realm export, prometheus, grafana, tempo configs

## 4. Containerisation
- [ ] `services/Dockerfile`: multi-stage, `--build-arg SERVICE=<svc>`, x64 JRE 21
- [ ] `services/frontend/Dockerfile`: node build → nginx
- [ ] `docker build -f services/Dockerfile --build-arg SERVICE=<svc> -t localhost:30002/microservices/<svc>:<tag> .`
- [ ] Always build locally for x64. Never use `saiupadhyayula007/*` images (arm64-only)

## 5. Image registry: Harbor on the cluster
- [ ] `k8s/platform/harbor/values-local.yaml`: small footprint, NodePort 30002, no TLS
- [ ] `scripts/windows/install-harbor.ps1` → `helm install harbor`
- [ ] Create project `microservices`; `docker login localhost:30002`
- [ ] `scripts/windows/common.ps1` + `build-and-push.ps1 [-Tag x] [-All|-Only svc]`
- [ ] Verify: images visible in Harbor UI, and a test pod can pull one

## 6. Kubernetes manifests (kustomize, declarative only)
- [ ] `k8s/infrastructure/core`: mysql, mongodb, zookeeper, kafka, schema-registry (laptop-sized requests/limits, PVCs, Services)
- [ ] `k8s/infrastructure/extras`: keycloak (+ keycloak-mysql), kafka-ui, prometheus, grafana, loki, tempo
- [ ] `k8s/apps/base/backend`: `common-config.yml` (ConfigMap), product / order / inventory Deployments + Services, actuator probes
- [ ] `k8s/apps/base/edge`: api-gateway, notification-service, frontend
- [ ] `k8s/apps/overlays/local`: backend only. Image tags **only** in its `images:` list
- [ ] `k8s/apps/overlays/full`: backend + edge
- [ ] ⛔ `kubectl kustomize <dir>` renders cleanly. Never `kubectl apply -f` a folder

## 7. Deploy to the laptop (backend-only default, about 3 GB)
- [ ] ⛔ Memory check: `wsl -d docker-desktop free -m`. Stop if < 2 GB available or the API server is slow
- [ ] `scripts/windows/deploy.ps1`
  - [ ] `kubectl apply -k k8s/infrastructure/core` → wait for Ready
  - [ ] `kubectl apply -k k8s/apps/overlays/local` → wait for Ready
- [ ] Smoke test via port-forward: create product → check stock → place order
- [ ] ⛔ `infrastructure/extras` / `overlays/full` (`deploy.ps1 -Full`) only after explicit approval

## 8. GitOps with Argo CD
- [ ] `argocd/projects/microservices.yaml` (AppProject)
- [ ] `argocd/applications/infrastructure.yaml`, `microservices-local.yaml`
- [ ] `argocd/bootstrap/root-app.yaml` (app-of-apps)
- [ ] ⛔ Memory check, then install Argo CD, apply the root app, sync
- [ ] From then on: change YAML/tags in git → Argo syncs. No `kubectl edit` / `set image` as final state

## 9. Release loop (repeat per change)
- [ ] Feature + Testcontainers integration test → `mvn -pl services/<svc> -am verify`
- [ ] `build-and-push.ps1 -Only <svc> -Tag <new>`
- [ ] Bump the tag in `k8s/apps/overlays/local` `images:` → commit → deploy / Argo sync
- [ ] Verify pods and logs (`kubectl logs deploy/<svc> --previous` if crashing)

## 10. Documentation
- [ ] `docs/laptop-setup.md`: ports, commands, fixes, troubleshooting
- [ ] `docs/architecture.png`
- [ ] `docs/Laptop-Kubernetes-Guide.pdf`: update the affected sections whenever the setup changes

## 11. Claude Code agentic setup (optional)
- [ ] `CLAUDE.md`: project facts + rules
- [ ] `.claude/skills`: new-service, add-feature, deploy-local, troubleshoot-cluster, release-version
- [ ] `.claude/agents`: code-reviewer, test-engineer, k8s-manifest-reviewer
- [ ] `.claude/hooks`: guard-bash, check-k8s, format-java, session-context
- [ ] `.mcp.json`: kubernetes + github MCP servers

---

### Most likely trouble spots
- **Harbor (phase 5):** the cluster has to be able to pull from `localhost:30002`. See `docs/laptop-setup.md`.
- **Memory (phase 7):** the VM has about 8 GB with no swap, so keep the backend-only default.
- **order-service (phase 2):** it has the most moving parts (Avro, Kafka, a circuit breaker and a downstream service).
