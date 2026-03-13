# Code Review Config — Portable Package

Multi-model code review pipeline for any GitHub repo. Three layers of automated review on every PR, plus periodic deep audits.

## What's Included

| File | Purpose |
|------|---------|
| `reusable-review.yml` | Reusable workflow — static checks + Codex logic + Claude convention |
| `reusable-audit.yml` | Reusable workflow — periodic codebase audit |
| `caller-review.yml` | Template — copy to consuming repo for PR reviews |
| `caller-audit.yml` | Template — copy to consuming repo for weekly audits |
| `REVIEW.md.template` | Template — project-specific review rules |
| `setup.sh` | One-command setup for any repo |

## Quick Start

### Option A: Setup Script

```bash
# In any repo:
bash setup.sh
```

### Option B: Manual

1. Copy `caller-review.yml` → `.github/workflows/code-review.yml`
2. Copy `caller-audit.yml` → `.github/workflows/weekly-audit.yml`
3. Copy `REVIEW.md.template` → `REVIEW.md` and customise
4. Set secrets: `gh secret set ANTHROPIC_API_KEY` + `gh secret set OPENAI_API_KEY`

## Extracting to Standalone Repo

To use `workflow_call` across repos, these reusable workflows must live in their own public repo:

```bash
# Create the config repo
gh repo create nbtee/code-review-config --public
cd code-review-config

# Copy reusable workflows
mkdir -p .github/workflows
cp reusable-review.yml .github/workflows/
cp reusable-audit.yml .github/workflows/

# Copy templates and setup
cp REVIEW.md.template .
cp setup.sh .
cp README.md .

git add -A && git commit -m "Initial reusable review workflows"
git push
```

Then consuming repos reference:
```yaml
uses: nbtee/code-review-config/.github/workflows/reusable-review.yml@main
```

## Configuration

### Inputs (PR Review)

| Input | Default | Description |
|-------|---------|-------------|
| `run-static` | `true` | Run tsc + lint |
| `run-codex` | `true` | Codex logic review |
| `run-claude` | `true` | Claude convention review |
| `claude-model` | `claude-sonnet-4-6` | Claude model |
| `claude-max-turns` | `10` | Max Claude turns |
| `node-version` | `20` | Node.js version |
| `package-manager` | `pnpm` | pnpm, npm, or yarn |
| `review-conventions` | `REVIEW.md` | Path to review rules |

### Inputs (Audit)

| Input | Default | Description |
|-------|---------|-------------|
| `claude-model` | `claude-sonnet-4-6` | Claude model |
| `claude-max-turns` | `30` | Max turns |
| `skip-paths` | `""` | Comma-separated skip paths |
| `issue-label` | `audit` | GitHub issue label |

## Cost Estimate (~20 PRs/month)

| Layer | Per Run | Monthly |
|-------|---------|---------|
| Static checks | $0 | $0 |
| Codex logic review | ~$0.10–0.30 | ~$4–6 |
| Claude convention review | ~$0.20–0.50 | ~$6–10 |
| Weekly audit | ~$2–5 | ~$10–20 |
| **Total** | | **~$20–36** |

## Secrets Required

| Secret | Required For |
|--------|-------------|
| `ANTHROPIC_API_KEY` | Claude review + audit |
| `OPENAI_API_KEY` | Codex review (optional) |
