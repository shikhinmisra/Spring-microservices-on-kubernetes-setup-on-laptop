<# Deploys infrastructure, then the microservices (images from Harbor).
   Default: backend only (k8s/infrastructure/core + k8s/apps/overlays/local) - fits a 16 GB laptop.
   -Full:   adds k8s/infrastructure/extras + gateway/notification/frontend (needs ~8-10 GB for Docker).
   Until Argo CD takes over, this is the manual equivalent of a sync.
   Run:  powershell -ExecutionPolicy Bypass -File scripts\windows\deploy.ps1 [-Full] #>
param([switch]$Full)
. (Join-Path $PSScriptRoot "common.ps1")
Use-DockerDesktopCluster

Step "Infrastructure"
kubectl apply -k "$RepoRoot\k8s\infrastructure\core"; Check "apply core infrastructure"
if ($Full) { kubectl apply -k "$RepoRoot\k8s\infrastructure\extras"; Check "apply extra infrastructure" }
kubectl wait --for=condition=available deployment --all --timeout=900s

$overlay = if ($Full) { "full" } else { "local" }
Step "Microservices (k8s/apps/overlays/$overlay)"
kubectl apply -k "$RepoRoot\k8s\apps\overlays\$overlay"; Check "apply apps"
kubectl wait --for=condition=available deployment --all --timeout=600s

Step "Status"
kubectl get pods -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,IMAGE:.spec.containers[0].image"
Write-Host @"

Product:   kubectl port-forward svc/product-service 8080:8080
Order:     kubectl port-forward svc/order-service 8081:8081
Inventory: kubectl port-forward svc/inventory-service 8082:8082
With -Full also: svc/api-gateway 9000:9000, svc/keycloak 8080:8080 (admin/admin), svc/grafana 3000:3000
"@ -ForegroundColor Green
