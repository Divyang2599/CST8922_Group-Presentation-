# AI-Assisted IaC Review - Demo Repo (Group 3)

This repo is the live demo for **AI-Assisted Infrastructure as Code Review and Deployment**.
It shows an AI reviewer catching real problems in a Terraform file before it deploys.

## What's deliberately broken in `main.tf`

| # | Issue | Category | Line to point at during demo |
|---|-------|----------|-------------------------------|
| 1 | `allow_nested_items_to_be_public = true` on the storage account | Security | `azurerm_storage_account` |
| 2 | NSG rule allows SSH (port 22) from `0.0.0.0/0` | Security | `azurerm_network_security_group` |
| 3 | VM sized `Standard_D8s_v3` (8 vCPU/32GB) for a "small test workload" | Cost waste | `azurerm_linux_virtual_machine` |
| 4 | Storage account named `myvm123`, VM named `testvm1` - no naming standard | Governance | resource names throughout |

These map directly to the CloudNova incident on the business-problem slide, so the demo
literally reproduces the scenario the presentation opens with.

## One-time setup (do this before demo day, not during)

1. Push this folder as a **new public or private GitHub repo**.
   - GitHub Models works on both, but if the repo is under an org, an org owner may need
     to enable GitHub Models access for the org first (Settings → Copilot → Models).
2. No secrets to add. No API key. No Azure subscription needed for the demo path -
   the workflow authenticates with GitHub's own `GITHUB_TOKEN`, which every Action gets
   automatically.
3. Confirm Actions are enabled: Settings → Actions → General → allow all actions.

## Running the demo live

1. Create a branch, e.g. `git checkout -b flawed-infra`.
2. Push `main.tf` as-is (it's already flawed) and open a **Pull Request** into `main`.
3. Watch the **Actions** tab - the `AI-Assisted IaC Review` workflow triggers automatically.
4. Once it finishes (~30-60 seconds), open the PR itself - the AI's findings appear as a
   comment, organized into Security / Naming & Governance / Cost / Errors.
5. Manually apply one or two of the suggested fixes to `main.tf` in the branch, commit,
   push again - the workflow reruns and the new comment shows fewer/no findings.
6. That's the "pipeline goes green" moment - talk through what `terraform apply` would do
   next in a real environment (not required to actually run `apply` live - a resource group
   in a real Azure subscription is optional and adds cost/failure risk for zero grading benefit).

## Why GitHub Models and not Azure OpenAI

Documented on the Governance slide, but the short version: GitHub Models authenticates
with the GitHub Actions token already available in every workflow - there is no separate
account, API key, or billing surface to misconfigure. That matters because our own team
hit an unexpected Azure OpenAI charge during early testing from an uncapped test account.
Production architecture (see slide 6) would use Azure AI Foundry behind a gateway with an
enforced budget cap; this repo uses the free, zero-billing-risk equivalent so the demo is
safe to run live, repeatedly, without supervision.

## Backup plan (do this regardless)

Record a full run-through (screen capture of: open PR → Actions run → AI comment
appears → fix applied → pipeline green) **before** presentation day. Live GitHub Actions
demos can be slow, hit GitHub Models rate limits, or have network hiccups in a classroom
Wi-Fi. If live breaks, you show the recording and keep talking - you never go silent.
