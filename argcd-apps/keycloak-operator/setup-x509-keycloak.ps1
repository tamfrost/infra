# Configure x509 authentication in Keycloak

Write-Host "Configuring Keycloak x509 authentication..." -ForegroundColor Cyan

# Get admin credentials
$adminUser = kubectl get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.username}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
$adminPass = kubectl get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# Get access token
$body = "grant_type=password&client_id=admin-cli&username=$adminUser&password=$adminPass"
$tokenResponse = Invoke-RestMethod -Uri "https://keycloak-local.apps-crc.testing/realms/master/protocol/openid-connect/token" -Method Post -Body $body -ContentType "application/x-www-form-urlencoded" -SkipCertificateCheck
$token = $tokenResponse.access_token

$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }

# Create x509-browser flow
Write-Host "Creating x509-browser flow..." -ForegroundColor Yellow
try {
    $copyFlow = @{ newName = "x509-browser" } | ConvertTo-Json
    Invoke-RestMethod -Uri "https://keycloak-local.apps-crc.testing/admin/realms/master/authentication/flows/browser/copy" -Headers $headers -Method Post -Body $copyFlow -SkipCertificateCheck | Out-Null
    Write-Host "x509-browser flow created" -ForegroundColor Green
} catch { Write-Host "Flow may already exist" -ForegroundColor Yellow }

# Add x509 authenticator
Start-Sleep -Seconds 2
Write-Host "Adding X509 authenticator..." -ForegroundColor Yellow
try {
    $addExecution = @{ provider = "auth-x509-client-username-form" } | ConvertTo-Json
    Invoke-RestMethod -Uri "https://keycloak-local.apps-crc.testing/admin/realms/master/authentication/flows/x509-browser/executions/execution" -Headers $headers -Method Post -Body $addExecution -SkipCertificateCheck | Out-Null
    Write-Host "X509 authenticator added" -ForegroundColor Green
} catch { Write-Host "Authenticator may already exist" -ForegroundColor Yellow }

# Set as default flow
Start-Sleep -Seconds 2
Write-Host "Setting as default flow..." -ForegroundColor Yellow
$realmUpdate = @{ browserFlow = "x509-browser" } | ConvertTo-Json
Invoke-RestMethod -Uri "https://keycloak-local.apps-crc.testing/admin/realms/master" -Headers $headers -Method Put -Body $realmUpdate -SkipCertificateCheck | Out-Null
Write-Host "x509-browser is now the default browser flow" -ForegroundColor Green

# Create test user
Write-Host "Creating test user..." -ForegroundColor Yellow
$newUser = @{
    username = "crc-client-test"
    enabled = $true
    email = "crc-client-test@example.com"
    credentials = @(@{ type = "password"; value = "password123"; temporary = $false })
} | ConvertTo-Json -Depth 10

try {
    Invoke-RestMethod -Uri "https://keycloak-local.apps-crc.testing/admin/realms/master/users" -Headers $headers -Method Post -Body $newUser -SkipCertificateCheck | Out-Null
    Write-Host "User crc-client-test created" -ForegroundColor Green
} catch { Write-Host "User may already exist" -ForegroundColor Yellow }

Write-Host ""
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "Username: crc-client-test" -ForegroundColor Cyan
Write-Host "Password: password123" -ForegroundColor Cyan
Write-Host "PFX Password: test123" -ForegroundColor Cyan
