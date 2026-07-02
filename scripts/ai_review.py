#!/usr/bin/env python3
"""
ai_review.py — AI-Assisted IaC Reviewer (Demo Build, Group 3)

What this does:
  1. Reads the Terraform file(s) changed in the PR.
  2. Sends the code to a model on GitHub Models (free, uses the
     workflow's own GITHUB_TOKEN — no API key, no card, no billing risk).
  3. Asks the model to review for four categories, matching the
     project's required scope: security, naming/governance, cost, errors.
  4. Writes a Markdown findings report that the workflow then posts
     as a comment on the pull request.

Why GitHub Models instead of Azure OpenAI / OpenAI direct:
  - Authenticates with the GITHUB_TOKEN GitHub Actions already provides.
  - No separate account, no credit card, no risk of an unexpected bill
    (see: Governance slide — our team learned this the hard way with a
    misconfigured Azure OpenAI test that resulted in an unexpected $215
    charge and a blocked account. This script cannot reproduce that
    failure mode because there is nothing to bill.)
  - Good enough model quality (GPT-4.1 / GPT-4o-mini class) for a code
    review demo of this size.

In a production environment (per our architecture slide) this same
review step would call Azure AI Foundry (GPT-5) behind an internal
gateway with an enforced spending cap, request quota, and audit log —
this script is deliberately the "safe demo" version of that same idea.
"""

import json
import os
import sys
import urllib.request
import urllib.error

GITHUB_MODELS_URL = "https://models.github.ai/inference/chat/completions"
MODEL = "openai/gpt-4o-mini"

REVIEW_PROMPT = """You are an automated Infrastructure-as-Code reviewer for a DevOps \
pipeline. Review the Terraform file below and return findings in ONLY the \
following four categories:

1. SECURITY — open ports, public access, missing encryption, overly \
   permissive rules.
2. NAMING & GOVERNANCE — resource names that don't follow a clear, \
   consistent, environment-aware naming standard.
3. COST — oversized or clearly wasteful resource choices for the \
   apparent workload.
4. ERRORS — syntax problems, missing required arguments, likely \
   misconfigurations.

For each finding give: the resource affected, the problem, why it \
matters, and a concrete fix (show corrected HCL where useful). Be \
specific and concise. If a category has no issues, say so briefly. \
Format your entire response in Markdown suitable for a GitHub PR \
comment, with one section per category.

Terraform file:
```hcl
{code}
```
"""


def read_terraform_file(path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def call_github_models(token: str, code: str) -> str:
    payload = {
        "model": MODEL,
        "messages": [
            {"role": "user", "content": REVIEW_PROMPT.format(code=code)}
        ],
        "temperature": 0.2,
    }

    req = urllib.request.Request(
        GITHUB_MODELS_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/vnd.github+json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            body = json.loads(resp.read().decode("utf-8"))
            return body["choices"][0]["message"]["content"]
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8", errors="replace")
        print(f"GitHub Models API error {e.code}: {error_body}", file=sys.stderr)
        sys.exit(1)


def main():
    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        print("GITHUB_TOKEN not set — this script must run inside "
              "GitHub Actions with 'permissions: models: read'.", file=sys.stderr)
        sys.exit(1)

    tf_path = sys.argv[1] if len(sys.argv) > 1 else "main.tf"
    code = read_terraform_file(tf_path)

    findings = call_github_models(token, code)

    header = "## AI Infrastructure Review\n\n" \
             f"Automated review of `{tf_path}` via GitHub Models (`{MODEL}`).\n\n---\n\n"

    output = header + findings

    with open("ai_review_output.md", "w", encoding="utf-8") as f:
        f.write(output)

    print(output)


if __name__ == "__main__":
    main()
