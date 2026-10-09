<# Deploys infrastructure, then the microservices (local overlay = images from Harbor).
   Until Argo CD takes over, this is the manual equivalent of a sync.
   Run:  powershell -ExecutionPolicy Bypass -File scripts\windows\deploy.ps1 #>
. (Join-Path $PSScriptRoot "common.ps1")
Use-DockerDesktopCluster

Step "Infrastructure"
kubectl apply -k "$RepoRoot\k8s\infrastructure"; Check "apply infrastructure"
kubectl wait --for=condition=available deployment --all --timeout=900s

Step "Microservices (k8s/apps/overlays/local)"
kubectl apply -k "$RepoRoot\k8s\apps\overlays\local"; Check "apply apps"
kubectl wait --for=condition=available deployment --all --timeout=600s

Step "Status"
kubectl get pods -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,IMAGE:.spec.containers[0].image"
Write-Host @"

Gateway:  kubectl port-forward svc/api-gateway 9000:9000  -> http://localhost:9000/swagger-ui.html
Keycloak: kubectl port-forward svc/keycloak 8080:8080     -> admin / admin
Grafana:  kubectl port-forward svc/grafana 3000:3000
"@ -ForegroundColor Green
