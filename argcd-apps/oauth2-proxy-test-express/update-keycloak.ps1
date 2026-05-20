$ErrorActionPreference = "Stop"

# Trust all certificates for PowerShell 5.1
if (-not ([System.Management.Automation.PSTypeName]'TrustAllCertsPolicy').Type) {
    add-type @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
}

[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

$KEYCLOAK_URL = "https://keycloak-local.apps-crc.testing"
$REALM = "master"
$ADMIN_PASSWORD = kubectl get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# Get token
$tokenResponse = Invoke-RestMethod -Method Post -Uri "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" -ContentType "application/x-www-form-urlencoded" -Body @{
    username = "temp-admin"
    password = $ADMIN_PASSWORD
    grant_type = "password"
    client_id = "admin-cli"
}

$TOKEN = $tokenResponse.access_token

# Get oauth2-proxy client
$client = Invoke-RestMethod -Method Get -Uri "$KEYCLOAK_URL/admin/realms/$REALM/clients?clientId=oauth2-proxy" -Headers @{ Authorization = "Bearer $TOKEN" }
$clientId = $client[0].id

# Get current client config
$currentClient = Invoke-RestMethod -Method Get -Uri "$KEYCLOAK_URL/admin/realms/$REALM/clients/$clientId" -Headers @{ Authorization = "Bearer $TOKEN" }

Write-Host "Current redirect URIs:" -ForegroundColor Cyan
$currentClient.redirectUris | ForEach-Object { Write-Host "  $_" }

$newUri = "https://test-express-app.apps-crc.testing/oauth2/callback"

if ($currentClient.redirectUris -notcontains $newUri) {
    $currentClient.redirectUris += $newUri
    $updateBody = $currentClient | ConvertTo-Json -Depth 10
    Invoke-RestMethod -Method Put -Uri "$KEYCLOAK_URL/admin/realms/$REALM/clients/$clientId" -Headers @{ Authorization = "Bearer $TOKEN"; "Content-Type" = "application/json" } -Body $updateBody | Out-Null
    Write-Host "`n✓ Added: $newUri" -ForegroundColor Green
} else {
    Write-Host "`n✓ Already configured: $newUri" -ForegroundColor Green
}
