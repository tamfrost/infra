#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs df-op and the df stack (df-lob + df-sim) on a cluster made by create-minc.

.DESCRIPTION
    Run it on a fresh cluster, or again at any time: every step is skipped or
    re-applied harmlessly when it's already done.

      1. Checks the cluster has what create-minc installs (OLM, Argo CD, cert-manager, Pomerium).
      2. Creates the "ghcr" pull secret in namespace df (the df-lob/df-sim images are private).
      3. Adds the DfStack health check to Argo CD.
      4. Creates the Argo CD app "df-op"; OLM installs the operator from its catalog.
      5. New stack only: applies dfstack-settings.yaml. From then on the console owns
         those settings (Installed Operators -> DF Stack -> df).
      6. Creates the Argo CD app "df-stack" (the image tags, from git).
      7. Waits for both apps and prints their URLs.

.PARAMETER RegistryUser
    ghcr.io user for pulling df-lob/df-sim. Only needed while the pull secret doesn't
    exist. Default: $env:CONTAINER_REGISTRY_USER, then ~/.minc/.env, then a prompt.

.PARAMETER RegistryPassword
    ghcr.io token (read:packages is enough). Same defaults, with CONTAINER_REGISTRY_PASSWORD.
#>
param(
    [string]$RegistryUser,
    [string]$RegistryPassword
)

$Namespace = "df"
$Stack = "df"
$Here = $PSScriptRoot

function Step($msg) { Write-Host "`n$msg" -ForegroundColor Cyan }
function Ok($msg) { Write-Host "  $msg" -ForegroundColor Green }
function Info($msg) { Write-Host "  $msg" }
function Fail($msg) { Write-Host "  $msg" -ForegroundColor Red; exit 1 }

# kubectl with stderr swallowed; the caller checks $LASTEXITCODE.
function Kube {
    $out = & kubectl @args 2>&1 | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
    return ($out -join "`n")
}

function Exists([string[]]$what) {
    $null = Kube get @what -o name
    return ($LASTEXITCODE -eq 0)
}

# Polls $test until it returns $true or $seconds pass.
function WaitFor([string]$what, [int]$seconds, [scriptblock]$test) {
    Write-Host "  Waiting for $what " -NoNewline
    $deadline = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $deadline) {
        if (& $test) { Write-Host " done" -ForegroundColor Green; return $true }
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 5
    }
    Write-Host " timed out" -ForegroundColor Yellow
    return $false
}

function ReadEnvFile([string]$path, [string]$key) {
    if (-not (Test-Path $path)) { return $null }
    foreach ($line in Get-Content $path) {
        if ($line -match "^\s*$key\s*=\s*(.*)$") { return $Matches[1].Trim().Trim('"') }
    }
    return $null
}

# --- 1. Prerequisites ---------------------------------------------------------
Step "1/7 Checking the cluster"
$context = Kube config current-context
Info "kube context: $context"
if (-not (Exists @("namespaces"))) { Fail "Can't reach the cluster. Is minc running?" }
if (-not (Exists @("crd", "subscriptions.operators.coreos.com"))) { Fail "OLM isn't installed. Create the cluster with create-minc first." }
if (-not (Exists @("namespace", "argocd"))) { Fail "Argo CD isn't installed (no argocd namespace). Run create-minc with Argo CD." }
if (-not (Exists @("clusterissuer", "local-ca-issuer"))) { Fail "cert-manager's local-ca-issuer is missing. Run create-minc." }
if (-not (Exists @("ingressclass", "pomerium"))) { Fail "Pomerium isn't installed. Run create-minc with Pomerium." }
Ok "OLM, Argo CD, cert-manager and Pomerium are there"

# --- 2. Pull secret -----------------------------------------------------------
Step "2/7 Pull secret for df-lob/df-sim"
$null = Kube create namespace $Namespace
if (Exists @("secret", "ghcr", "-n", $Namespace)) {
    Ok "secret ghcr already exists in $Namespace"
} else {
    $envFile = Join-Path $HOME ".minc/.env"
    if (-not $RegistryUser) { $RegistryUser = $env:CONTAINER_REGISTRY_USER }
    if (-not $RegistryUser) { $RegistryUser = ReadEnvFile $envFile "CONTAINER_REGISTRY_USER" }
    if (-not $RegistryUser) { $RegistryUser = Read-Host "  ghcr.io user" }
    if (-not $RegistryPassword) { $RegistryPassword = $env:CONTAINER_REGISTRY_PASSWORD }
    if (-not $RegistryPassword) { $RegistryPassword = ReadEnvFile $envFile "CONTAINER_REGISTRY_PASSWORD" }
    if (-not $RegistryPassword) {
        $secure = Read-Host "  ghcr.io token (read:packages)" -AsSecureString
        $RegistryPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
    }
    if (-not $RegistryUser -or -not $RegistryPassword) { Fail "No registry login given." }
    $null = Kube -n $Namespace create secret docker-registry ghcr --docker-server=ghcr.io `
        "--docker-username=$RegistryUser" "--docker-password=$RegistryPassword"
    if ($LASTEXITCODE -ne 0) { Fail "Couldn't create the pull secret." }
    Ok "created secret ghcr in $Namespace"
}

# --- 3. Argo CD health check --------------------------------------------------
Step "3/7 DfStack health check in Argo CD"
$null = Kube -n argocd patch configmap argocd-cm --type merge --patch-file (Join-Path $Here "argocd-cm-health.yaml")
if ($LASTEXITCODE -ne 0) { Fail "Couldn't patch argocd-cm." }
Ok "argocd-cm patched"

# --- 4. Operator --------------------------------------------------------------
Step "4/7 Operator (Argo CD app df-op -> OLM)"
$null = Kube apply -f (Join-Path $Here "application-operator.yaml")
if ($LASTEXITCODE -ne 0) { Fail "Couldn't create the df-op Application." }
$installed = WaitFor "OLM to install df-op" 600 {
    $csv = Kube -n openshift-operators get subscription df-op -o "jsonpath={.status.installedCSV}"
    if (-not $csv) { return $false }
    (Kube -n openshift-operators get csv $csv -o "jsonpath={.status.phase}") -eq "Succeeded"
}
if (-not $installed) {
    Fail "The operator didn't install. See: kubectl -n openshift-operators get subscription df-op -o yaml"
}
Ok ("installed " + (Kube -n openshift-operators get subscription df-op -o "jsonpath={.status.installedCSV}"))

# --- 5. Starting settings (new stack only) ------------------------------------
Step "5/7 Stack settings"
$managers = Kube -n $Namespace get dfstack $Stack --show-managed-fields -o "jsonpath={.metadata.managedFields[*].manager}"
if ($managers -match "df-console") {
    Ok "stack exists and its settings are managed in the console; leaving them alone"
} else {
    # Applied under their own field manager, so Argo CD (which only applies
    # the tags) never removes them and the console can change them freely.
    $null = Kube apply --server-side --field-manager=df-console -f (Join-Path $Here "dfstack-settings.yaml")
    if ($LASTEXITCODE -ne 0) { Fail "Couldn't apply dfstack-settings.yaml." }
    Ok "applied dfstack-settings.yaml"
}

# --- 6. Stack -----------------------------------------------------------------
Step "6/7 Stack (Argo CD app df-stack -> image tags from git)"
$null = Kube apply -f (Join-Path $Here "application-stack.yaml")
if ($LASTEXITCODE -ne 0) { Fail "Couldn't create the df-stack Application." }
Ok "df-stack Application applied"

# --- 7. Wait ------------------------------------------------------------------
Step "7/7 Waiting for df-lob and df-sim"
$ready = WaitFor "the stack to be ready" 600 {
    (Kube -n $Namespace get dfstack $Stack -o "jsonpath={.status.conditions[?(@.type=='Ready')].status}") -eq "True"
}
if (-not $ready) {
    $msg = Kube -n $Namespace get dfstack $Stack -o "jsonpath={.status.conditions[?(@.type=='Ready')].message}"
    Write-Host "  Not ready yet: $msg" -ForegroundColor Yellow
    Write-Host "  Check: kubectl -n $Namespace get pods" -ForegroundColor Yellow
    exit 1
}

$lob = Kube -n $Namespace get dfstack $Stack -o "jsonpath={.status.lob.url}"
$sim = Kube -n $Namespace get dfstack $Stack -o "jsonpath={.status.sim.url}"
Write-Host "`nDone." -ForegroundColor Green
# Pomerium is published on port 9444 by create-minc
if ($lob) { Write-Host "  df-lob: $($lob):9444" }
if ($sim) { Write-Host "  df-sim: $($sim):9444" }
Write-Host "  Settings: console -> Operators -> Installed Operators -> DF Stack -> $Stack"
Write-Host "  Image tags: manifests/df-op/stack/dfstack.yaml in this repo"
