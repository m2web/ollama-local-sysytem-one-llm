[CmdletBinding()]
param(
    [string]$ResponsePath = "$PSScriptRoot\response.json",
    [string]$ExpectedChoice = ""
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
$probEntries = @($probs.PSObject.Properties)
$probSum = ($probEntries | ForEach-Object { [double]$_.Value } | Measure-Object -Sum).Sum
$topEntry = $probEntries | Sort-Object { [double]$_.Value } -Descending | Select-Object -First 1

$expectedMatch = if ($ExpectedChoice) {
    $labelAns.choice -eq $ExpectedChoice
} else {
    $labelAns.choice -eq $topEntry.Name
}

$resultProps = [ordered]@{
    Model               = $resp.model
    AnswerType          = $labelAns.type
    SelectedChoice      = $labelAns.choice
    TopProbabilityKey   = $topEntry.Name
    ExpectedChoiceMatch = $expectedMatch
    Confidence          = $labelAns.confidence
    ValidConfidence     = ($labelAns.confidence -ge 0.0 -and $labelAns.confidence -le 1.0)
}

foreach ($entry in $probEntries) {
    $propName = "Prob" + $entry.Name.Substring(0,1).ToUpper() + $entry.Name.Substring(1)
    $resultProps[$propName] = $entry.Value
}

$resultProps["ProbabilitySum"]      = [math]::Round($probSum, 4)
$resultProps["ValidProbabilitySum"] = ([math]::Abs($probSum - 1.0) -le 0.02)
$resultProps["InputTokens"]         = $resp.usage.input_tokens
$resultProps["OutputTokens"]        = $resp.usage.output_tokens

$validationResult = [PSCustomObject]$resultProps
$validationResult | Format-List

if (-not ($validationResult.ExpectedChoiceMatch -and $validationResult.ValidConfidence -and $validationResult.ValidProbabilitySum)) {
    throw "One or more response schema assertions failed."
}
