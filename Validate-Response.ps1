[CmdletBinding()]
param(
    [string]$ResponsePath = "$PSScriptRoot\response.json"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ResponsePath)) {
    throw "Response file not found at $ResponsePath"
}

$resp = Get-Content -Path $ResponsePath -Raw | ConvertFrom-Json
$labelAns = $resp.answers.label

if ($null -eq $labelAns) {
    throw "Validation failed: Missing 'answers.label' in response."
}

$probs = $labelAns.probabilities
$probSum = [double]$probs.billing + [double]$probs.bug + [double]$probs.account

$validationResult = [PSCustomObject]@{
    Model               = $resp.model
    AnswerType          = $labelAns.type
    SelectedChoice      = $labelAns.choice
    ExpectedChoiceMatch = ($labelAns.choice -eq "bug")
    Confidence          = $labelAns.confidence
    ValidConfidence     = ($labelAns.confidence -ge 0.0 -and $labelAns.confidence -le 1.0)
    ProbBilling         = $probs.billing
    ProbBug             = $probs.bug
    ProbAccount         = $probs.account
    ProbabilitySum      = [math]::Round($probSum, 4)
    ValidProbabilitySum = ([math]::Abs($probSum - 1.0) -le 0.02)
    InputTokens         = $resp.usage.input_tokens
    OutputTokens        = $resp.usage.output_tokens
}

$validationResult | Format-List

if (-not ($validationResult.ExpectedChoiceMatch -and $validationResult.ValidConfidence -and $validationResult.ValidProbabilitySum)) {
    throw "One or more response schema assertions failed."
}
