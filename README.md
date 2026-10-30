<div align="center">

# ⚡ SYSTEM ONE // LOCAL DISPATCH
### Zero-Token-Generation Classification with Ollama & `nimble`

*Fast, instinctual routing at the edge — before a generative LLM ever wakes up.*

</div>

---

> **Why generate text when you only need a decision?**  
> Standard LLM pipelines burn decode tokens, latency, and compute just to emit `"category": "work"` inside a fragile JSON string.  
> **System One** flips the paradigm: you hand the local `nimble` model a **state** and a set of **criteria**, and it evaluates the probability distribution directly—returning calibrated probabilities and a confidence score with **`0` output tokens**.

```mermaid
flowchart LR
    classDef input fill:#0f172a,stroke:#38bdf8,stroke-width:2px,color:#f8fafc
    classDef engine fill:#1e1b4b,stroke:#818cf8,stroke-width:2px,color:#f8fafc
    classDef route fill:#064e3b,stroke:#34d399,stroke-width:2px,color:#ecfdf5

    S["📥 Raw Event State<br/><i>'Reviewing AI roadmap...'</i>"]:::input
    C["🧭 Criteria Matrix<br/><i>family | work | leisure</i>"]:::input
    O(("⚡ /v1/systemone<br/><b>model: nimble</b><br/>output_tokens: 0")):::engine
    D1["🏡 family<br/><code>p = 0.0005</code>"]:::input
    D2["💼 work<br/><code>p = 0.9985</code>"]:::route
    D3["🎸 leisure<br/><code>p = 0.0010</code>"]:::input

    S --> O
    C --> O
    O --> D1
    O ==>|"Selected (conf: 0.9978)"| D2
    O --> D3
```

---

## 🧠 System 1 vs. System 2 at the Local Endpoint

Inspired by Daniel Kahneman’s cognitive model, this repository explores **System 1** inference on a local Ollama instance (`http://localhost:11434/v1/systemone`):

| Dimension | System 2 (`/v1/chat/completions`) | System 1 (`/v1/systemone`) |
| :--- | :--- | :--- |
| **Cognitive Mode** | Deliberative, autoregressive token generation | Instantaneous, instinctual classification |
| **Output Tokens** | `15 – 200+` tokens (JSON formatting + reasoning) | **`0` tokens** |
| **Failure Surface** | Hallucinated keys, broken JSON, prompt injection | Strictly bounded to your declared `criteria` keys |
| **Signal Richness** | Single string answer | Full probability simplex ($\sum p_i = 1.0$) + confidence |
| **Byte Guardrails** | Unbounded until context window | Enforced `< 64 KiB` schema/text wire check |

---

## 🔬 Live Telemetry from This Repo

Below are actual captured runs from [`fam-work-leisure-nimble-llm.ps1`](./fam-work-leisure-nimble-llm.ps1) against the local `nimble` model. Notice `output_tokens: 0` across every classification:

<table>
  <thead>
    <tr>
      <th align="left">Input State</th>
      <th align="center">Winner</th>
      <th align="right"><code>p(family)</code></th>
      <th align="right"><code>p(work)</code></th>
      <th align="right"><code>p(leisure)</code></th>
      <th align="right">Confidence</th>
      <th align="right">Tokens (In / Out)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><i>"My wife Jackie wants us to go see the grandkids."</i></td>
      <td align="center"><b><code>family</code></b></td>
      <td align="right"><code>0.9945</code></td>
      <td align="right"><code>0.0023</code></td>
      <td align="right"><code>0.0031</code></td>
      <td align="right"><b>99.18%</b></td>
      <td align="right"><code>214 / 0</code></td>
    </tr>
    <tr>
      <td><i>"Reviewing AI development roadmap and team oversight sprint tasks."</i></td>
      <td align="center"><b><code>work</code></b></td>
      <td align="right"><code>0.0005</code></td>
      <td align="right"><code>0.9985</code></td>
      <td align="right"><code>0.0010</code></td>
      <td align="right"><b>99.78%</b></td>
      <td align="right"><code>213 / 0</code></td>
    </tr>
    <tr>
      <td><i>"Heading to a live music show and relaxing with friends this weekend."</i></td>
      <td align="center"><b><code>leisure</code></b></td>
      <td align="right"><code>0.0002</code></td>
      <td align="right"><code>0.0007</code></td>
      <td align="right"><code>0.9991</code></td>
      <td align="right"><b>99.87%</b></td>
      <td align="right"><code>215 / 0</code></td>
    </tr>
  </tbody>
</table>

<details>
<summary><b>🔍 Inspect Raw Wire Contract (Request &rarr; Response)</b></summary>
<br/>

**Request (`POST http://localhost:11434/v1/systemone`)**
```json
{
  "model": "nimble",
  "state": "Reviewing AI development roadmap and team oversight sprint tasks.",
  "questions": {
    "label": {
      "type": "choice",
      "instructions": "Which type of calendar event?",
      "criteria": {
        "family": "Wife Jackie, kids, grandkids, in-laws",
        "work": "AI Development, Team Oversight",
        "leisure": "Live music, football game, relax with friends"
      }
    }
  }
}
```

**Response ([`response-work-2026-10-30_11-19-39.json`](./response-work-2026-10-30_11-19-39.json))**
```json
{
  "model": "nimble",
  "answers": {
    "label": {
      "type": "choice",
      "choice": "work",
      "probabilities": {
        "family": 0.0005086825370004281,
        "leisure": 0.0009613621490445472,
        "work": 0.9985299553139549
      },
      "confidence": 0.9977949329709322
    }
  },
  "usage": {
    "input_tokens": 213,
    "output_tokens": 0
  }
}
```
</details>

---

## 🗂️ Field Guide to the Workbench

Instead of a bloated framework, everything here is pure, dependency-free PowerShell talking straight to the HTTP wire as raw UTF-8 byte arrays:

### 1. [`fam-work-leisure-nimble-llm.ps1`](./fam-work-leisure-nimble-llm.ps1) — *The Personal Calendar Router*
Picks a random real-life scenario (Family, Work, or Leisure), validates that the UTF-8 payload stays under the `64 KiB` System One ceiling, fires it at `localhost:11434/v1/systemone`, and stamps an audit file named after the winning choice (`response-<outcome>-<timestamp>.json`).

```powershell
.\fam-work-leisure-nimble-llm.ps1
```

### 2. [`Test-OllamaSystemOne.ps1`](./Test-OllamaSystemOne.ps1) — *Parameterized Harness*
A flexible CLI runner. Run it out-of-the-box to triage an incident ticket (`billing` vs `bug` vs `account`), or feed it any custom state or external JSON file:

```powershell
# Default support-ticket triage (500 server error -> bug)
.\Test-OllamaSystemOne.ps1

# Pass a custom state inline
.\Test-OllamaSystemOne.ps1 -State "Can I get a receipt for last month's invoice?"

# Drive from an external JSON payload file
.\Test-OllamaSystemOne.ps1 -PayloadPath .\payload.json
```

### 3. [`Validate-Response.ps1`](./Validate-Response.ps1) — *Mathematical & Schema Assertions*
Verifies that the model's output isn't just syntactically valid, but mathematically sound:
- Asserts `confidence` $\in [0.0, 1.0]$
- Verifies the probability simplex sums to `1.0` ($\pm 0.02$ floating-point tolerance)
- Checks the expected classification winner

```powershell
.\Test-OllamaSystemOne.ps1
.\Validate-Response.ps1 -ResponsePath .\response.json
```

---

<div align="center">
  <sub>Built for fast local routing • Powered by Ollama <code>/v1/systemone</code> &amp; <code>nimble</code></sub>
</div>
