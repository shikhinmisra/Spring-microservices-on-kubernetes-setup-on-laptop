<# Builds images for this PC's CPU and pushes them to Harbor.
   Default: backend only (product, order, inventory).  -All: every service + frontend.  -Only x,y: just those.
   Run:  powershell -ExecutionPolicy Bypass -File scripts\windows\build-and-push.ps1 [-Tag 1.0] [-All] [-Only product-service] #>
param([string]$Tag = "1.0", [switch]$All, [string[]]$Only)
. (Join-Path $PSScriptRoot "common.ps1")
Set-Location $RepoRoot
$targets = if ($Only) { $Only } elseif ($All) { $Services + "frontend" } else { $Backend }

foreach ($s in $targets) {
    $img = "$Registry/$Project/${s}:$Tag"
    Step "Building $img"
    if ($s -eq "frontend") { docker build -t $img services\frontend }
    else { docker build -f services\Dockerfile --build-arg SERVICE=$s -t $img . }
    Check "build $s"
    docker push $img; Check "push $s"
}
Write-Host "`nPushed tag $Tag. To deploy it, set newTag: `"$Tag`" in k8s\apps\overlays\local\kustomization.yaml" -ForegroundColor Green
