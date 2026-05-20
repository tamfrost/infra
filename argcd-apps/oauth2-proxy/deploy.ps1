#!/usr/bin/env pwsh
# Deploy oauth2-proxy via ArgoCD

Write-Host "Deploying OAuth2-Proxy via ArgoCD..." -ForegroundColor Cyan

# Apply RBAC permissions
Write-Host "`nApplying RBAC permissions..." -ForegroundColor Yellow
kubectl apply -f rbac.yaml

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to apply RBAC" -ForegroundColor Red
    exit 1
}

# Apply the ArgoCD Application
Write-Host "`nApplying ArgoCD Application..." -ForegroundColor Yellow
kubectl apply -f application.yaml

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to apply ArgoCD Application" -ForegroundColor Red
    exit 1
}

Write-Host "`nWaiting for ArgoCD to sync the application..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Create the route
Write-Host "`nCreating OpenShift Route..." -ForegroundColor Yellow
kubectl apply -f route.yaml

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to create route" -ForegroundColor Red
    exit 1
}

# Remove conflicting df-sim route if it exists
Write-Host "`nRemoving conflicting df-sim route (if exists)..." -ForegroundColor Yellow
kubectl delete route df-sim -n df-sim 2>$null

# Check ArgoCD application status
Write-Host "`nArgoCD Application Status:" -ForegroundColor Cyan
kubectl get application oauth2-proxy -n openshift-gitops

Write-Host "`nOAuth2-Proxy Pods:" -ForegroundColor Cyan
kubectl get pods -n oauth2-proxy

Write-Host "`nOAuth2-Proxy Route:" -ForegroundColor Cyan
kubectl get route -n oauth2-proxy

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "OAuth2-Proxy Deployment Summary" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Application URL: https://df-sim.apps-crc.testing/" -ForegroundColor Cyan
Write-Host "Callback URL: https://df-sim.apps-crc.testing/oauth2/callback" -ForegroundColor Cyan
Write-Host "Keycloak: https://keycloak-local.apps-crc.testing/" -ForegroundColor Cyan
Write-Host "`nTest User: crc-client-test" -ForegroundColor Yellow
Write-Host "Test Password: password123" -ForegroundColor Yellow
Write-Host "Client Certificate: crc-client-test.pfx (password: test123)" -ForegroundColor Yellow
Write-Host "`nTo sync manually:" -ForegroundColor Magenta
Write-Host "  kubectl patch application oauth2-proxy -n openshift-gitops --type merge -p '{`"operation`":{`"initiatedBy`":{`"username`":`"admin`"},`"sync`":{`"revision`":`"HEAD`"}}}'" -ForegroundColor Gray
Write-Host "`nTo check logs:" -ForegroundColor Magenta
Write-Host "  kubectl logs -n oauth2-proxy -l app.kubernetes.io/name=oauth2-proxy" -ForegroundColor Gray
