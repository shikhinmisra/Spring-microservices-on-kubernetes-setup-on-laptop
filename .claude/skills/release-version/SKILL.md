---
name: release-version
description: Release a new version of one or more services - verify, build the x64 image, push to Harbor, bump the tag in the kustomize overlay and commit (Argo CD-ready). Use when the user asks to release, ship, publish, or deploy a new version.
argument-hint: "<service|all-backend> <tag>"
disable-model-invocation: true
---

# Release $ARGUMENTS

Tags: semantic `MAJOR.MINOR.PATCH` (e.g. `1.1.0`). Never reuse or overwrite a tag that is already in Harbor.

1. **Verify**: `mvn -pl services/<svc> -am verify` for each service. Stop on failure.
2. **Build + push** (needs Docker Desktop running and Harbor at http://localhost:30002):
   - Windows: `powershell -ExecutionPolicy Bypass -File scripts\windows\build-and-push.ps1 -Tag <tag> -Only <svc>[,<svc>]`
   - Manual: `docker build -f services/Dockerfile --build-arg SERVICE=<svc> -t localhost:30002/microservices/<svc>:<tag> .`
     then `docker push localhost:30002/microservices/<svc>:<tag>` (frontend: `docker build -t ... services/frontend`).
   - Confirm it exists: `curl -s http://localhost:30002/api/v2.0/projects/microservices/repositories/<svc>/artifacts?q=tags%3D<tag>`.
3. **Bump the tag in git** (this is the deployment record): edit `newTag` for the service in
   `k8s/apps/overlays/local/kustomization.yaml` (and `overlays/full`). Render with `kubectl kustomize k8s/apps/overlays/local`.
4. **Commit**: `release(<svc>): <tag>` with a one-line summary of what changed. Push only if the user asked.
5. **Roll out**:
   - Argo CD installed (`kubectl get ns argocd`): it syncs from git after the push — check `kubectl -n argocd get applications`.
   - Otherwise: `kubectl apply -k k8s/apps/overlays/local` then `kubectl rollout status deploy/<svc> --timeout=180s`.
6. **Smoke test** via port-forward (`kubectl port-forward svc/<svc> <port>:<port>`): `/actuator/health` is UP and one real endpoint works.
7. Report: service, old tag -> new tag, image digest, rollout result.
Rollback = set `newTag` back to the previous tag, commit, apply/sync.
