#!/usr/bin/env pwsh
# Deploy df-op (operator + DfStack) via Argo CD

Write-Host "Deploying df-op via Argo CD..." -ForegroundColor Cyan

# Images on ghcr.io are private: OLM (catalog, bundle), the operator and the
# apps pull with a secret named "ghcr", created once per cluster (never kept
# in git) in each of these namespaces, e.g.
#   kubectl -n openshift-marketplace create secret docker-registry ghcr --docker-server=ghcr.io `
#     --docker-username=<user> --docker-password=<PAT with read:packages>
foreach ($ns in "openshift-marketplace", "openshift-operators", "df") {
    kubectl get secret ghcr -n $ns *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Missing pull secret 'ghcr' in namespace $ns (see comment above)" -ForegroundColor Yellow
    }
}

Write-Host "`nAdding the DfStack health check to argocd-cm..." -ForegroundColor Yellow
kubectl -n argocd patch configmap argocd-cm --type merge --patch-file "$PSScriptRoot/argocd-cm-health.yaml"
if ($LASTEXITCODE -ne 0) { Write-Host "Failed to patch argocd-cm" -ForegroundColor Red; exit 1 }

Write-Host "`nApplying Argo CD Applications..." -ForegroundColor Yellow
kubectl apply -f "$PSScriptRoot/application-operator.yaml" -f "$PSScriptRoot/application-stack.yaml"
if ($LASTEXITCODE -ne 0) { Write-Host "Failed to apply Applications" -ForegroundColor Red; exit 1 }

Write-Host "`nDone. Watch with: kubectl -n argocd get applications df-op df-stack" -ForegroundColor Green
