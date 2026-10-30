[CmdletBinding()]
param(
    [string]$State = "Our checkout has returned 500 errors since 9am.",
    [string]$Model = "nimble",
    [string]$PayloadPath = "",
    [string]$ResponsePath = "$PSScriptRoot\response.json",
    [string]$Endpoint = "http://localhost:11434/v1/systemone"
)

$ErrorActionPreference = "Stop"

# Use external JSON file if provided; otherwise build the payload inline
if ($PayloadPath -and (Test-Path $PayloadPath)) {
    $rawJson = Get-Content -Path $PayloadPath -Raw
} else {
    $payload = @{
        model     = $Model
        state     = $State
        questions = @{
            label = @{
                type         = "choice"
                instructions = "Which label fits this ticket?"
                criteria     = @{
                    billing = "Payments and refunds"
                    bug     = "Software errors and 500 server failures"
                    account = "Login and account access"
                }
            }
        }
    }
    $rawJson = $payload | ConvertTo-Json -Depth 10 -Compress
}

# Verify UTF-8 byte constraints
$utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($rawJson)

if ($utf8Bytes.Length -gt 65536) {
    throw "Payload exceeds 64 KiB text/schema limit ($($utf8Bytes.Length) bytes)."
}
if ($utf8Bytes.Length -ge 33554432) {
    throw "Payload exceeds 32 MiB total request limit ($($utf8Bytes.Length) bytes)."
}

# Execute POST /v1/systemone
try {
    $response = Invoke-RestMethod `
        -Uri $Endpoint `
        -Method Post `
        -Body $utf8Bytes `
        -ContentType "application/json; charset=utf-8" `
        -TimeoutSec 180
} catch {
    $errBody = $_.ErrorDetails.Message
    throw "System One API call failed: $($_.Exception.Message) | Details: $errBody"
}

if ($ResponsePath) {
    $response | ConvertTo-Json -Depth 10 | Set-Content -Path $ResponsePath -Encoding UTF8
}

Write-Output ($response | ConvertTo-Json -Depth 10)
