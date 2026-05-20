# Deploy Keycloak using the Keycloak Operator

Write-Host "Deploying Keycloak..." -ForegroundColor Cyan

# Apply RBAC first
Write-Host "`n1. Setting up RBAC permissions..." -ForegroundColor Yellow
kubectl apply -f rbac.yaml

# Deploy Keycloak instance
Write-Host "`n2. Creating Keycloak instance..." -ForegroundColor Yellow
kubectl apply -f keycloak-instance.yaml

# Create route
Write-Host "`n3. Creating route..." -ForegroundColor Yellow
kubectl apply -f route.yaml

# Wait for deployment
Write-Host "`n4. Waiting for Keycloak to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Check status
Write-Host "`nKeycloak Status:" -ForegroundColor Cyan
kubectl get keycloak -n keycloak
kubectl get pods -n keycloak -l app=keycloak
kubectl get route -n keycloak

# Get admin credentials
Write-Host "`nAdmin Credentials:" -ForegroundColor Green
Write-Host "Username: " -NoNewline
kubectl get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.username}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
Write-Host "Password: " -NoNewline
kubectl get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

Write-Host "`nAccess Keycloak at: https://keycloak-local.apps-crc.testing/" -ForegroundColor Cyan
