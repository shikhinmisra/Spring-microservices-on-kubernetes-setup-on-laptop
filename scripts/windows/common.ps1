# Shared helpers, dot-sourced by the other scripts.
$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Registry = "localhost:30002"
$Project  = "microservices"
$Services = "api-gateway", "product-service", "order-service", "inventory-service", "notification-service"
function Step($msg)   { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Check($what) { if ($LASTEXITCODE -ne 0) { Write-Host "FAILED: $what" -ForegroundColor Red; exit 1 } }
function Use-DockerDesktopCluster {
    kubectl config use-context docker-desktop | Out-Null; Check "switch to docker-desktop context"
    $node = kubectl get nodes -o jsonpath='{.items[0].metadata.name}'
    if ($node -ne "docker-desktop") {
        Write-Host "Cluster type is not kubeadm (node '$node'). Docker Desktop > Settings > Kubernetes > Kubeadm." -ForegroundColor Red; exit 1
    }
}
