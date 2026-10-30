---
title: "The Rise of Utility LLMs: Routing Personal Calendar Events Locally with Ollama System One"
date: 2026-10-30T12:00:00-04:00
draft: false
tags: ["AI", "LocalLLM", "Ollama", "PowerShell", "Software Architecture"]
categories: ["Software Development"]
summary: "Why we should stop using heavyweight generative chat models for simple triage—and how to use a local System One 'Utility LLM' in Ollama to classify Google Calendar events with zero output tokens."
description: "Why we should stop using heavyweight generative chat models for simple triage—and how to use a local System One 'Utility LLM' in Ollama to classify Google Calendar events with zero output tokens."
---

If you have spent any time building practical software with Large Language Models over the past couple of years, you have probably noticed an architectural anti-pattern that has quietly become the industry default: **we use heavyweight, general-purpose reasoning models for everything.**

Need to synthesize a multi-document architecture review? Call a frontier chat model.  
Need to decide whether a one-sentence string belongs in bucket `A`, `B`, `C`, or `D`? We *still* call a frontier chat model—stuffing a system prompt full of rules like *"Respond ONLY with valid JSON, do not include markdown backticks"* and hoping the autoregressive token decoder doesn't hallucinate an extra key.

Using a massive generative model just to classify a string is like spinning up a full browser engine just to `grep` a log file.

As AI systems mature, the immediate future isn't a single monolithic model doing every job. Instead, we are seeing the rise of **Utility LLMs**—small, single-purpose local models that behave much more like Unix command-line tools. They do one job, they do it deterministically in milliseconds on local hardware, and they don't burn generative output tokens to do it.

Recently, while working on a personal project to automatically categorize and route events for my **Google Calendar**, I put this exact pattern to the test using **Ollama’s `/v1/systemone` endpoint** and the **`nimble`** model.

Here is a look under the hood at how a local System One LLM works, why `output_tokens: 0` changes the game for routing and triage, and the PowerShell script you can use to run it yourself.

---

## The Personal Project: Routing Life into Family, Work, Leisure, and Faith

The problem I wanted to solve for my Google Calendar workflow was straightforward. When a new calendar entry or natural-language note comes in, I want it automatically categorized into one of four buckets—**Family**, **Work**, **Leisure**, or **Faith**—so I can color-code events, route them to sub-calendars, or track how my time is actually being spent:

* **Family:** `"Wife Jackie, kids, grandkids, in-laws"`
* **Work:** `"AI Development, Team Oversight"`
* **Leisure:** `"Live music, football game, relax with friends"`
* **Faith:** `"Church on Sundays, teaching Sunday school, church community group"`

Wait a second—do I really want to ship personal notes about my wife Jackie, our grandkids, or teaching Sunday school out to a third-party cloud API just to get back a category label? And do I really need a model to *generate* text token-by-token when the set of valid answers is already known ahead of time?

No. What I needed was a local **System 1 classifier**.

---

## System 1 vs. System 2: The Plumbing Beneath the Porcelain

In Daniel Kahneman’s classic book *Thinking, Fast and Slow*, human cognition is split into two modes:

1. **System 1** operates automatically and instinctively—you read a sentence and immediately *know* whether it’s about family, church, or work without consciously deliberating.
2. **System 2** allocates slow, effortful, step-by-step reasoning to complex problems.

Most LLM APIs (`/v1/chat/completions`) are built like **System 2**—even when you ask a trivial question, the engine runs an autoregressive generation loop, sampling one token after another until it hits a stop sequence.

Ollama’s **`/v1/systemone`** endpoint flips that model on its head. Instead of asking the model to *write a response*, you pass it:

* **`state`**: The raw input text you want evaluated.
* **`questions`**: One or more structured classification questions.
* **`criteria`**: A dictionary of valid keys and their semantic descriptions.

Instead of generating prose, the `nimble` model evaluates your `state` against the `criteria` in a single forward pass and returns a **calibrated probability distribution** across your exact keys—with **`0` output tokens generated**.

```text
+---------------------------------------------------------------------------------+
|  📥 INPUT STATE                                                                 |
|  "Preparing my Sunday school lesson and meeting with our church community group"|
+---------------------------------------------------------------------------------+
                                        |
                                        v
+---------------------------------------------------------------------------------+
|  🧭 CRITERIA MATRIX                                                             |
|  • family  : "Wife Jackie, kids, grandkids, in-laws"                            |
|  • work    : "AI Development, Team Oversight"                                   |
|  • leisure : "Live music, football game, relax with friends"                    |
|  • faith   : "Church on Sundays, teaching Sunday school, church community group"|
+---------------------------------------------------------------------------------+
                                        |
                                        v
+---------------------------------------------------------------------------------+
|  ⚡ OLLAMA /v1/systemone (model: nimble)                                        |
|  Single forward pass • input_tokens: 230 • output_tokens: 0                     |
+---------------------------------------------------------------------------------+
       |                     |                     |                     |
       v                     v                     v                     v
+----------------+    +----------------+    +----------------+    +----------------+
| 🏡 family      |    | 💼 work        |    | 🎸 leisure     |    | ⛪ faith       |
| p = 0.0012     |    | p = 0.0004     |    | p = 0.0006     |    | p = 0.9977 [✓] |
+----------------+    +----------------+    +----------------+    +----------------+
```

---

## The Wire Contract: What Goes In and What Comes Out

Let’s look at the raw JSON payload (`payload.json`) we send to `http://localhost:11434/v1/systemone`:

```json
{
  "model": "nimble",
  "state": "My wife Jackie wants us to go see the grandkids.",
  "questions": {
    "label": {
      "type": "choice",
      "instructions": "Which type of calendar event?",
      "criteria": {
        "family": "Wife Jackie, kids, grandkids, in-laws",
        "work": "AI Development, Team Oversight",
        "leisure": "Live music, football game, relax with friends",
        "faith": "Church on Sundays, teaching Sunday school, church community group"
      }
    }
  }
}
```

And here is the response when routing a church-related event (`response-faith.json`):

```json
{
  "model": "nimble",
  "answers": {
    "label": {
      "type": "choice",
      "choice": "faith",
      "probabilities": {
        "family": 0.001241829104821934,
        "leisure": 0.000618294019283412,
        "work": 0.000419876875894654,
        "faith": 0.997720000000000000
      },
      "confidence": 0.9965800000000001
    }
  },
  "usage": {
    "input_tokens": 230,
    "output_tokens": 0
  }
}
```

Look closely at three things in that JSON response:

1. **No schema hallucinations:** It is structurally impossible for the model to invent an unmapped fifth category because it is scoring the fixed `criteria` dictionary you supplied.
2. **Calibrated probabilities & confidence:** You don't just get `"choice": "faith"`. You get the full probability simplex (`0.0012 + 0.0006 + 0.0004 + 0.9977 = 1.0000`) plus an overall `confidence` score (`0.9966`). If an event overlaps categories (say, a church family picnic where `confidence` drops below `0.65`), your script knows immediately and can flag it for review.
3. **`"output_tokens": 0`:** All the work happens on the input pass (`230` input tokens). Zero tokens were decoded.

---

## Hands-On: The PowerShell Calendar Router

To test all four calendar categories in practice, I put together [`fam-work-leisure-nimble-llm.ps1`](https://github.com/m2web/ollama-local-sysytem-one-llm/blob/main/fam-work-leisure-nimble-llm.ps1).

One important plumbing detail when working with the `/v1/systemone` endpoint: the API enforces a strict **64 KiB UTF-8 byte ceiling** on the text and schema payload. Instead of letting PowerShell’s `Invoke-RestMethod` guess the string encoding, we serialize the payload to compressed JSON, convert it to an explicit UTF-8 byte array, verify the byte length up front, and send it over the wire:

```powershell
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
```

### Empirical Results Across All Four Buckets

Running the classifier across all four test states produced the following results:

| Input Calendar State | Selected Choice | `p(family)` | `p(work)` | `p(leisure)` | `p(faith)` | Confidence | Tokens (In / Out) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| *"My wife Jackie wants us to go see the grandkids."* | **`family`** | **`0.9941`** | `0.0021` | `0.0029` | `0.0008` | **99.18%** | `228 / 0` |
| *"Reviewing AI development roadmap and team oversight sprint tasks."* | **`work`** | `0.0004` | **`0.9985`** | `0.0008` | `0.0003` | **99.78%** | `227 / 0` |
| *"Heading to a live music show and relaxing with friends this weekend."* | **`leisure`** | `0.0002` | `0.0005` | **`0.9989`** | `0.0004` | **99.87%** | `229 / 0` |
| *"Preparing my Sunday school lesson and meeting with our church community group."* | **`faith`** | `0.0012` | `0.0004` | `0.0006` | **`0.9977`** | **99.66%** | `230 / 0` |

Every single run classified cleanly with **>99% confidence** and **zero output tokens**.

---

## Where This Goes Next: Composable Utility LLMs

Working with `/v1/systemone` and `nimble` for something as personal and practical as my Google Calendar reinforced a broader architectural lesson: **not every AI problem is a chat problem.**

As we build out the next generation of local and hybrid AI systems, expect to see a clear separation of duties:

* **System 1 Utility LLMs** sitting at the edge—classifying calendar events, routing webhooks, tagging emails, and acting as sub-second gatekeepers with zero output tokens and complete local privacy.
* **System 2 Reasoning LLMs** woken up *only* when a task genuinely requires multi-step synthesis, planning, or prose generation.

If you want to experiment with the script or wire up your own local classifier, all of the code, sample payloads, and captured responses are available on GitHub:

👉 **[m2web/ollama-local-sysytem-one-llm](https://github.com/m2web/ollama-local-sysytem-one-llm)**
