# Spring microservices on Kubernetes (laptop), built from scratch

We are building this project **from an empty repo**, phase by phase, following
`docs/build-from-scratch-checklist.md`. The target: Spring Boot 3.2 / Java 21 microservices on Docker Desktop
Kubernetes on a Windows laptop, images in a local Harbor registry, managed by Argo CD (GitOps) at the end.

## Where we are
- **Current phase: 0** (update this line when a phase's gate passes)
- Work only on the current phase. Do not create files that belong to later phases.
- At the end of a phase: run its gate, tick the boxes in the checklist, update the line above, and tell me.

## Decisions already made (don't re-ask, don't change without asking)
- Laptop: Windows x64, 16 GB RAM. Docker Desktop VM about 8 GB, no swap. kubectl context `docker-desktop`, cluster type **kubeadm**.
- Build: Maven multi-module. Parent `pom.xml` at the root, one module per service under `services/<name>/`.
- Java package: `com.techie.microservices.<short>`, where `<short>` is `product`, `order`, `inventory`, `notification` or `gateway`.
- Services and ports:
  | service | port | depends on |
  |---|---|---|
  | product-service | 8080 | MongoDB |
  | order-service | 8081 | MySQL (Flyway), Kafka + Schema Registry (Avro), calls inventory |
  | inventory-service | 8082 | MySQL (Flyway) |
  | notification-service | 8083 | Kafka (Avro consumer) |
  | api-gateway | 9000 | Keycloak (OAuth2 resource server) |
  | frontend | 80 (nginx) | Angular + Tailwind, OIDC via Keycloak |
- Build order: product → inventory → order → notification → api-gateway → frontend.
- Registry: Harbor at `http://localhost:30002` (NodePort, no TLS), project `microservices`,
  images `localhost:30002/microservices/<svc>:<tag>`.
- Layout (create each folder only when its phase starts):
  ```
  services/                      Java modules, shared services/Dockerfile, frontend/
  local-dev/                     docker-compose for running without Kubernetes (optional)
  k8s/platform/harbor/           Helm values for Harbor
  k8s/infrastructure/core/       mysql, mongodb, zookeeper, kafka, schema-registry
  k8s/infrastructure/extras/     keycloak, kafka-ui, prometheus, grafana, loki, tempo
  k8s/apps/base/{backend,edge}/  backend = product/order/inventory, edge = gateway/notification/frontend
  k8s/apps/overlays/{local,full}/  local = backend only (default), full = everything
  argocd/                        AppProject, Applications, root app-of-apps
  scripts/windows/               install-harbor.ps1, build-and-push.ps1, deploy.ps1 (PowerShell)
  docs/                          checklist, laptop-setup.md, architecture
  ```

## Commands (each becomes available in the phase that creates it)
```
mvn -pl services/<svc> -am verify                                   # phase 2+: build + tests for one service
docker build -f services/Dockerfile --build-arg SERVICE=<svc> -t localhost:30002/microservices/<svc>:<tag> .   # phase 4+
scripts/windows/install-harbor.ps1                                  # phase 5
scripts/windows/build-and-push.ps1 [-Tag x] [-All|-Only svc]         # phase 5+
kubectl kustomize <kustomization dir>                               # phase 6+: render before applying
scripts/windows/deploy.ps1 [-Full]                                  # phase 7+
kubectl get pods; kubectl logs deploy/<svc> --previous; docker stats --no-stream
```

## Rules that always apply
- **Tests first**: every feature gets an `@SpringBootTest` integration test with Testcontainers (MongoDB, MySQL, Kafka)
  and WireMock for calls to other services. Never use the cluster's databases in tests. Run
  `mvn -pl services/<svc> -am verify` before calling work done. Report failures and never skip tests.
- **Images**: always build locally for x64 and push to Harbor. Never use `saiupadhyayula007/*` images (arm64-only).
  Pin versions; never use `latest`.
- **Kubernetes**:
  - Every container has requests and limits sized for the laptop, plus readiness/liveness probes on actuator health.
  - Image tags live ONLY in the overlay `images:` list.
  - Never `kubectl apply -f` a folder. Use `-k` on a kustomization or the scripts.
  - Keep `k8s/` declarative and Argo CD-friendly. `kubectl edit` / `set image` is never the final state; change the YAML in git.
- **Memory**: backend-only by default (product, order, inventory + core infra + Harbor, about 3 GB). Before deploying
  anything, check `wsl -d docker-desktop free -m`. If < 2 GB is available or the API server is slow, add nothing.
  Never apply `infrastructure/extras` or `overlays/full`, or install Argo CD, without asking me.
- **Ask first**: deleting Kubernetes resources, `helm uninstall`, deleting files, force-push, changing Docker/WSL settings,
  adding a new dependency or tool not listed above.
  **Just do, then tell me**: scaling down, restarting pods, rebuilding/pushing images.
- **Git**: small commits per step, on a branch, never straight to `main`. Messages like `feat(order): ...`, `docs: ...`.
- **Docs**: when ports, commands or layout change, update `docs/laptop-setup.md` and this file.
