# Spring microservices on Kubernetes (laptop)

Spring Boot 3.2 / Java 21 microservices deployed to Docker Desktop Kubernetes on a Windows laptop,
images in a local Harbor registry, repo laid out for Argo CD (GitOps) next.

## Project facts
- Laptop: Windows x64, 16 GB RAM. Docker VM ~7.8 GB, no swap. kubectl context `docker-desktop`, cluster type **kubeadm**.
- Java code: `services/<name>/src/main/java/com/techie/microservices/<name>/`; parent `pom.xml` at root.
- Services: product (8080, MongoDB), order (8081, MySQL + Kafka/Avro, calls inventory), inventory (8082, MySQL/Flyway),
  notification (8083, Kafka), api-gateway (9000, Keycloak), frontend (Angular).
- Kubernetes: `k8s/infrastructure/{core,extras}`, `k8s/apps/base/{backend,edge}`, `k8s/apps/overlays/{local,full}` (kustomize).
  Image tags live ONLY in the overlay `images:` list. `argocd/` holds app-of-apps scaffolding (not installed yet).
- Registry: Harbor `http://localhost:30002`, project `microservices`, images `localhost:30002/microservices/<svc>:<tag>`.
- Docs: `docs/Laptop-Kubernetes-Guide.pdf` (user's living guide), `docs/laptop-setup.md` (fixes + troubleshooting).

## Key commands
```
mvn -pl services/<svc> -am verify                              # build + tests for one service
docker build -f services/Dockerfile --build-arg SERVICE=<svc> -t localhost:30002/microservices/<svc>:<tag> .
kubectl kustomize k8s/apps/overlays/local                      # render before applying
scripts/windows/build-and-push.ps1 [-Tag x] [-All|-Only svc]    # images -> Harbor
scripts/windows/deploy.ps1 [-Full]                             # core infra + backend (default) / everything
kubectl get pods; kubectl logs deploy/<svc> --previous; docker stats --no-stream
```

## Rules that always apply
- **Backend-only by default**: product, order, inventory + core infra + Harbor (~3 GB). Before deploying, check memory
  (`wsl -d docker-desktop free -m` or Docker Desktop RAM). If < 2 GB available or the API server is slow, do not add anything.
  Never apply `infrastructure/extras` or `overlays/full` without asking me.
- **Images**: always build locally for x64 and push to Harbor. Never use `saiupadhyayula007/*` images (arm64-only).
- **Never `kubectl apply` a whole folder with `-f`**; use `-k` on a kustomization or the scripts.
- **Tests**: every new/changed feature gets an `@SpringBootTest` integration test using Testcontainers (MongoDB, MySQL, Kafka),
  not the cluster's databases. Run `mvn -pl services/<svc> -am verify` before calling work done; report failures, never skip tests.
- **Ask first**: deleting Kubernetes resources, `helm uninstall`, deleting files, force-push, changing Docker/WSL settings.
  **Just do, then tell me**: scaling down, restarting pods, rebuilding/pushing images.
- Keep `k8s/` declarative and Argo CD-friendly: no manual `kubectl edit`/`set image` as the final state — change the YAML in git.
- When the setup changes (ports, commands, layout), update `docs/laptop-setup.md` and tell me which PDF sections need updating.
