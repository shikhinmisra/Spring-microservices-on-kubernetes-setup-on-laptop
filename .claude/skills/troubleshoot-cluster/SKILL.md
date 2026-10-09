---
name: troubleshoot-cluster
description: Diagnose and fix problems in the laptop Kubernetes setup - pods Pending/CrashLoopBackOff/ImagePullBackOff, exec format error, kubectl TLS handshake timeout, Harbor unreachable, out-of-memory Docker VM. Use when something in the cluster is broken or slow.
---

# Troubleshoot the laptop cluster

Work from symptoms; read-only commands first. Report evidence (command + key output line) for every conclusion.

| Symptom | Check | Usual fix |
|---|---|---|
| kubectl `TLS handshake timeout` / Docker UI frozen | `wsl -d docker-desktop free -m`, `docker stats --no-stream` | VM out of memory. Restart Docker Desktop; then scale everything outside the default set to 0 (`kubectl scale deploy/<x> --replicas=0`). Long-term: `%UserProfile%\.wslconfig` `memory=10GB` (ask first). |
| `CrashLoopBackOff` | `kubectl logs deploy/<svc> --previous --tail=80` | `exec format error` = arm64 image -> rebuild via `release-version`. Connection refused to DB/Kafka -> dependency not ready; check core infra pods. |
| `Pending` | `kubectl describe pod <pod>` Events | `Insufficient memory` -> free memory. `ErrImagePull` -> see next row. |
| `ImagePullBackOff` | image name in `kubectl get pod <pod> -o jsonpath='{.spec.containers[0].image}'`; `curl http://localhost:30002/api/v2.0/ping` | Image/tag missing in Harbor -> build+push; tag typo in overlay -> fix `newTag`. Harbor down -> `kubectl -n harbor get pods`. |
| Harbor not reachable from Windows | `kubectl -n harbor get svc harbor` | Type must be LoadBalancer on 30002: `kubectl -n harbor patch svc harbor --type=json --patch-file k8s/platform/harbor/service-loadbalancer-patch.json` |
| Two pods for one deployment, old image | `kubectl get rs -l app=<svc>` | Stuck rollout; fix the new pod's error, old ReplicaSet goes away after success. |
| Order fails with inventory error | `kubectl logs deploy/order-service`, inventory pod status | inventory-service down or unknown SKU. |

Rules: scaling down and restarting pods is allowed (tell the user afterwards). Deleting resources, `helm uninstall`,
or changing Docker/WSL settings needs the user's OK first. Never `kubectl apply -f` a folder to "reset" things.
After fixing, add any new symptom/fix pair to `docs/laptop-setup.md`.
