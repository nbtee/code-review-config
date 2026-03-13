# Code Review Config

Multi-model code review pipeline for any GitHub repo. Three layers of automated review on every PR, plus weekly deep audits.

## Setup (one command)

From any repo root:

```bash
curl -sL https://raw.githubusercontent.com/nbtee/code-review-config/main/setup.sh | bash
```

This will:
1. Install PR review workflow (static checks + Codex logic + Claude conventions)
2. Optionally install weekly deep audit (Monday 2am UTC)
3. Create `REVIEW.md` template for your project conventions
4. Add API key references to `.env.local` (commented, for local reference)
5. Prompt to set GitHub secrets
6. Print a checklist of what to do next

## What It Does

### On Every PR (3-layer review)

| Layer | What | Cost |
|-------|------|------|
| **Static checks** | `tsc --noEmit` + `eslint` | Free |
| **Codex logic review** | OpenAI Codex scans for bugs, security issues, edge cases | ~$0.20/PR |
| **Claude convention review** | Claude checks PR against your `REVIEW.md` conventions | ~$0.35/PR |

### Weekly Audit (Monday 2am UTC)

Claude Opus deep-scans the full codebase for dead code, architecture drift, security gaps, and type safety issues. Creates a GitHub issue with structured findings.

## Manual Setup

If you prefer not to use the setup script:

1. Copy workflows:
   ```bash
   mkdir -p .github/workflows
   curl -sL https://raw.githubusercontent.com/nbtee/code-review-config/main/caller-review.yml > .github/workflows/code-review.yml
   curl -sL https://raw.githubusercontent.com/nbtee/code-review-config/main/caller-audit.yml > .github/workflows/weekly-audit.yml
   ```

2. Create review conventions:
   ```bash
   curl -sL https://raw.githubusercontent.com/nbtee/code-review-config/main/REVIEW.md.template > REVIEW.md
   # Edit REVIEW.md to match your project
   ```

3. Set GitHub secrets:
   ```bash
   gh secret set ANTHROPIC_API_KEY
   gh secret set OPENAI_API_KEY
   ```

4. Commit and push:
   ```bash
   git add .github/ REVIEW.md
   git commit -m "feat: add code review pipeline"
   git push
   ```

## Secrets

| Secret | Required | Purpose |
|--------|----------|---------|
| `ANTHROPIC_API_KEY` | Yes | Claude convention review + weekly audit |
| `OPENAI_API_KEY` | Yes (or set `run-codex: false`) | Codex logic review |
| `SLACK_WEBHOOK_URL` | No | Slack notifications for weekly audit |

## Configuration

### PR Review Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `run-static` | `true` | Run tsc + lint |
| `run-codex` | `true` | Codex logic review |
| `run-claude` | `true` | Claude convention review |
| `claude-model` | `claude-sonnet-4-6` | Claude model for convention review |
| `claude-max-turns` | `10` | Max Claude turns per review |
| `node-version` | `20` | Node.js version |
| `package-manager` | `pnpm` | pnpm, npm, or yarn |
| `review-conventions` | `REVIEW.md` | Path to your project review rules |

### Weekly Audit Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `claude-model` | `claude-sonnet-4-6` | Claude model for audit |
| `claude-max-turns` | `30` | Max turns |
| `skip-paths` | `""` | Comma-separated paths to skip |
| `issue-label` | `audit` | GitHub issue label for findings |

## Repos Using This

- [potentia-hub](https://github.com/nbtee/potentia-hub) — Aptus learning platform
- [learntechfast](https://github.com/nbtee/learntechfast)
- [watch_agent](https://github.com/nbtee/watch_agent)

## Cost Estimate (~20 PRs/month)

| Layer | Per Run | Monthly |
|-------|---------|---------|
| Static checks | $0 | $0 |
| Codex logic review | ~$0.10–0.30 | ~$4–6 |
| Claude convention review | ~$0.20–0.50 | ~$6–10 |
| Weekly audit | ~$2–5 | ~$10–20 |
| **Total** | | **~$20–36** |
