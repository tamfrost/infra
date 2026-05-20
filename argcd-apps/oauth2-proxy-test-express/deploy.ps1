# Deploy OAuth2-Proxy for Test Express App
Write-Host "Deploying OAuth2-Proxy for test-express..." -ForegroundColor Cyan

# Apply RBAC
Write-Host "`nApplying RBAC configuration..." -ForegroundColor Yellow
kubectl apply -f $PSScriptRoot\rbac.yaml

# Update Keycloak OAuth2-Proxy client to add new redirect URL
Write-Host "`nUpdating Keycloak client with new redirect URL..." -ForegroundColor Yellow
$KEYCLOAK_URL = "https://keycloak-local.apps-crc.testing"
$REALM = "master"

# Get admin token
$ADMIN_PASSWORD = kubectl get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

$tokenResponse = Invoke-RestMethod -Method Post `
    -Uri "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" `
    -ContentType "application/x-www-form-urlencoded" `
    -Body @{
        username = "temp-admin"
        password = $ADMIN_PASSWORD
        grant_type = "password"
        client_id = "admin-cli"
    } `
    -SkipCertificateCheck

$TOKEN = $tokenResponse.access_token

# Get existing client
$client = Invoke-RestMethod -Method Get `
    -Uri "$KEYCLOAK_URL/admin/realms/$REALM/clients?clientId=oauth2-proxy" `
    -Headers @{ Authorization = "Bearer $TOKEN" } `
    -SkipCertificateCheck

$clientId = $client[0].id

# Get current client config
$currentClient = Invoke-RestMethod -Method Get `
    -Uri "$KEYCLOAK_URL/admin/realms/$REALM/clients/$clientId" `
    -Headers @{ Authorization = "Bearer $TOKEN" } `
    -SkipCertificateCheck

# Add new redirect URI if not already present
$redirectUris = $currentClient.redirectUris
if ($redirectUris -notcontains "https://test-express-app.apps-crc.testing/oauth2/callback") {
    $redirectUris += "https://test-express-app.apps-crc.testing/oauth2/callback"
    
    $currentClient.redirectUris = $redirectUris
    $updateBody = $currentClient | ConvertTo-Json -Depth 10

    Invoke-RestMethod -Method Put `
        -Uri "$KEYCLOAK_URL/admin/realms/$REALM/clients/$clientId" `
        -Headers @{ 
            Authorization = "Bearer $TOKEN"
            "Content-Type" = "application/json"
        } `
        -Body $updateBody `
        -SkipCertificateCheck
    
    Write-Host "✓ Keycloak client updated with test-express-app redirect URI" -ForegroundColor Green
} else {
    Write-Host "✓ Redirect URI already exists in Keycloak" -ForegroundColor Green
}

# Deploy ArgoCD application
Write-Host "`nDeploying ArgoCD Application..." -ForegroundColor Yellow
kubectl apply -f $PSScriptRoot\application.yaml

Write-Host "`nWaiting for deployment..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Show status
Write-Host "`n=== Deployment Status ===" -ForegroundColor Cyan
kubectl get application oauth2-proxy-test-express -n openshift-gitops
kubectl get pods -n oauth2-proxy-test
kubectl get route -n oauth2-proxy-test

Write-Host "`n✓ OAuth2-Proxy for test-express deployed!" -ForegroundColor Green
Write-Host "Access at: https://test-express-app.apps-crc.testing/" -ForegroundColor Yellow
