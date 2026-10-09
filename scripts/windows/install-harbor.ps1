<# Installs Harbor in Docker Desktop Kubernetes and creates the public 'microservices' project.
   Run from anywhere:  powershell -ExecutionPolicy Bypass -File scripts\windows\install-harbor.ps1 #>
param([string]$HarborPassword = "Harbor12345")
. (Join-Path $PSScriptRoot "common.ps1")
Use-DockerDesktopCluster

if (-not (Get-Command helm -ErrorAction SilentlyContinue)) {
    winget install --id Helm.Helm -e --accept-source-agreements --accept-package-agreements
    Write-Host "Helm installed - open a new PowerShell window and re-run." -ForegroundColor Yellow; exit 1
}

Step "Installing Harbor"
helm repo add harbor https://helm.goharbor.io 2>$null
helm repo update harbor; Check "helm repo update"
helm upgrade --install harbor harbor/harbor -n harbor --create-namespace `
    -f "$RepoRoot\k8s\platform\harbor\values-local.yaml" --set harborAdminPassword=$HarborPassword `
    --wait --timeout 15m; Check "helm install harbor"

# Docker Desktop forwards LoadBalancer (not NodePort) services to Windows localhost.
kubectl -n harbor patch svc harbor --type=json --patch-file "$RepoRoot\k8s\platform\harbor\service-loadbalancer-patch.json"

Step "Waiting for Harbor at http://$Registry"
for ($i = 0; $i -lt 60; $i++) {
    try { Invoke-RestMethod "http://$Registry/api/v2.0/ping" -TimeoutSec 5 | Out-Null; $ok = $true; break } catch { Start-Sleep 5 }
}
if (-not $ok) { Write-Host "Harbor not reachable on http://$Registry - check: kubectl -n harbor get pods,svc" -ForegroundColor Red; exit 1 }

Step "Creating public project '$Project'"
$auth = @{ Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:$HarborPassword")) }
try {
    Invoke-RestMethod -Method Post "http://$Registry/api/v2.0/projects" -Headers $auth -ContentType "application/json" `
        -Body (@{ project_name = $Project; metadata = @{ public = "true" } } | ConvertTo-Json) | Out-Null
    Write-Host "Created."
} catch { if ($_.Exception.Response.StatusCode.value__ -eq 409) { Write-Host "Already exists." } else { throw } }

$HarborPassword | docker login $Registry -u admin --password-stdin; Check "docker login"
Write-Host "`nHarbor UI: http://$Registry  (admin / $HarborPassword)" -ForegroundColor Green
