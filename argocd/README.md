# Argo CD (GitOps continuous delivery) — next phase

Nothing in this folder is applied yet. It is laid out so that adding Argo CD is a matter of installing it and applying one file.

```
argocd/
├── bootstrap/root-app.yaml        # app-of-apps: the only thing you apply by hand
├── projects/microservices.yaml    # AppProject limiting repo + destination
└── applications/
    ├── infrastructure.yaml        # syncs k8s/infrastructure          (sync-wave 0)
    └── microservices-local.yaml   # syncs k8s/apps/overlays/local      (sync-wave 1)
```

## Planned steps
1. Install Argo CD:
   `kubectl create namespace argocd`
   `kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml`
2. If this repo is private, register it: Argo CD UI → Settings → Repositories (use a GitHub fine-grained token, read-only).
3. Bootstrap: `kubectl apply -n argocd -f argocd/bootstrap/root-app.yaml`
4. CD loop: CI builds and pushes `localhost:30002/microservices/<service>:<tag>` to Harbor, then commits the new
   `newTag` in `k8s/apps/overlays/local/kustomization.yaml`. Argo CD detects the commit and rolls out.
   (Argo CD Image Updater can automate the tag bump later.)

New environments = new folder under `k8s/apps/overlays/` + a matching Application here.
