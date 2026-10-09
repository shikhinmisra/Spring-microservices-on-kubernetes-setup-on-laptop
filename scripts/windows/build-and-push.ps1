<# Builds all service images + frontend for this PC's CPU and pushes them to Harbor.
   Run:  powershell -ExecutionPolicy Bypass -File scripts\windows\build-and-push.ps1 [-Tag 1.0] [-Only product-service] #>
param([string]$Tag = "1.0", [string[]]$Only)
. (Join-Path $PSScriptRoot "common.ps1")
Set-Location $RepoRoot
$targets = if ($Only) { $Only } else { $Services + "frontend" }

foreach ($s in $targets) {
    $img = "$Registry/$Project/${s}:$Tag"
    Step "Building $img"
    if ($s -eq "frontend") { docker build -t $img services\frontend }
    else { docker build -f services\Dockerfile --build-arg SERVICE=$s -t $img . }
    Check "build $s"
    docker push $img; Check "push $s"
}
Write-Host "`nPushed tag $Tag. To deploy it, set newTag: `"$Tag`" in k8s\apps\overlays\local\kustomization.yaml" -ForegroundColor Green
