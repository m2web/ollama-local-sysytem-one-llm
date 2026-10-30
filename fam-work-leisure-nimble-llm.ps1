$criteria = @{
    family  = "Wife Jackie, kids, grandkids, in-laws"
    work    = "AI Development, Team Oversight"
    leisure = "Live music, football game, relax with friends"
    faith   = "Church on Sundays, teaching Sunday school, church community group"
}

$famPayload = @{
    model     = "nimble"
    state     = "My wife Jackie wants us to go see the grandkids."
    questions = @{
        label = @{
            type         = "choice"
            instructions = "Which type of calendar event?"
            criteria     = $criteria
        }
    }
}

$workPayload = @{
    model     = "nimble"
    state     = "Reviewing AI development roadmap and team oversight sprint tasks."
    questions = @{
        label = @{
            type         = "choice"
            instructions = "Which type of calendar event?"
            criteria     = $criteria
        }
    }
}

$leisurePayload = @{
    model     = "nimble"
    state     = "Heading to a live music show and relaxing with friends this weekend."
    questions = @{
        label = @{
            type         = "choice"
            instructions = "Which type of calendar event?"
            criteria     = $criteria
        }
    }
}

$faithPayload = @{
    model     = "nimble"
    state     = "Preparing my Sunday school lesson and meeting with our church community group."
    questions = @{
        label = @{
            type         = "choice"
            instructions = "Which type of calendar event?"
            criteria     = $criteria
        }
    }
}

# Randomly select one of the 4 payloads
$payload = @($famPayload, $workPayload, $leisurePayload, $faithPayload) | Get-Random

Write-Host "Randomly selected payload state: $($payload.state)" -ForegroundColor Cyan

$jsonBody = $payload | ConvertTo-Json -Depth 10 -Compress
$utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)

if ($utf8Bytes.Length -gt 65536) {
    throw "Payload exceeds 64 KiB text/schema limit ($($utf8Bytes.Length) bytes)."
}

try {
    $response = Invoke-RestMethod `
        -Uri "http://localhost:11434/v1/systemone" `
        -Method Post `
        -Body $utf8Bytes `
        -ContentType "application/json; charset=utf-8" `
        -TimeoutSec 120
}
catch {
    $errBody = $_.ErrorDetails.Message
    throw "System One API call failed (HTTP $($_.Exception.Response.StatusCode.value__)): $errBody"
}

$outcome = $response.answers.label.choice
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$outputFile = Join-Path -Path $PSScriptRoot -ChildPath "response-$outcome-$timestamp.json"

$formattedJson = $response | ConvertTo-Json -Depth 10
$formattedJson | Set-Content -Path $outputFile -Encoding UTF8

Write-Host "Saved response to: $outputFile" -ForegroundColor Green
$formattedJson
