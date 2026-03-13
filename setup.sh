#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# Code Review Pipeline — One-Command Setup
#
# Run from any repo root:
#   curl -sL https://raw.githubusercontent.com/nbtee/code-review-config/main/setup.sh | bash
#   — or —
#   bash setup.sh
#
# What it does:
#   1. Installs PR review workflow (Codex + Claude + static checks)
#   2. Optionally installs weekly deep audit
#   3. Creates REVIEW.md template for project conventions
#   4. Adds required keys to .env.local (as commented reference)
#   5. Sets GitHub secrets (for CI)
#   6. Prints a checklist of what to do next
# ──────────────────────────────────────────────────────────────

set -euo pipefail

REPO_OWNER="nbtee"
CONFIG_REPO="code-review-config"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/${REPO_OWNER}/${CONFIG_REPO}/${BRANCH}"

# Colours
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
DIM='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Code Review Pipeline — Setup                    ║${NC}"
echo -e "${BOLD}║  3-layer PR review + weekly deep audit            ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ── Prerequisites ─────────────────────────────────────────────
if ! command -v gh &> /dev/null; then
  echo -e "  ${YELLOW}!${NC} gh CLI not found. Install: https://cli.github.com/"
  exit 1
fi

if ! gh auth status &> /dev/null 2>&1; then
  echo -e "  ${YELLOW}!${NC} gh not authenticated. Run: gh auth login"
  exit 1
fi

REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || true)
if [ -z "$REPO" ]; then
  echo -e "  ${YELLOW}!${NC} Not in a GitHub repository. Run this from your repo root."
  exit 1
fi

echo -e "  ${CYAN}Repo:${NC}  $REPO"
echo -e "  ${CYAN}From:${NC}  ${REPO_OWNER}/${CONFIG_REPO}"
echo ""

# ── Step 1: Install PR review workflow ────────────────────────
echo -e "${BOLD}Step 1/5 — PR Review Workflow${NC}"
mkdir -p .github/workflows
cat > .github/workflows/code-review.yml << 'WORKFLOW'
# Multi-model PR review: static checks > Codex logic > Claude conventions
# Secrets needed: ANTHROPIC_API_KEY, OPENAI_API_KEY
# Customise: REVIEW.md in repo root

name: Code Review

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  review:
    uses: nbtee/code-review-config/.github/workflows/reusable-review.yml@main
    with:
      run-codex: true
      run-claude: true
    secrets:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
      OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
WORKFLOW
echo -e "  ${GREEN}+${NC} .github/workflows/code-review.yml"

# ── Step 2: Install weekly audit workflow ─────────────────────
echo ""
echo -e "${BOLD}Step 2/5 — Weekly Audit Workflow${NC}"
read -p "  Install weekly deep audit (Monday 2am UTC)? [Y/n] " -n 1 -r
echo ""
INSTALL_AUDIT=${REPLY:-Y}
if [[ $INSTALL_AUDIT =~ ^[Yy]?$ ]]; then
  cat > .github/workflows/weekly-audit.yml << 'WORKFLOW'
# Weekly codebase audit: dead code, architecture drift, security gaps
# Secrets needed: ANTHROPIC_API_KEY
# Optional: SLACK_WEBHOOK_URL for Slack notifications

name: Weekly Code Audit

on:
  schedule:
    - cron: "0 2 * * 1"
  workflow_dispatch:

jobs:
  audit:
    uses: nbtee/code-review-config/.github/workflows/reusable-audit.yml@main
    secrets:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
WORKFLOW
  echo -e "  ${GREEN}+${NC} .github/workflows/weekly-audit.yml"
else
  echo -e "  ${DIM}skipped${NC}"
fi

# ── Step 3: Create REVIEW.md if missing ──────────────────────
echo ""
echo -e "${BOLD}Step 3/5 — Review Conventions${NC}"
if [ -f "REVIEW.md" ]; then
  echo -e "  ${GREEN}ok${NC} REVIEW.md already exists"
else
  curl -sL "${RAW_BASE}/REVIEW.md.template" > REVIEW.md 2>/dev/null || cat > REVIEW.md << 'TEMPLATE'
# Code Review Guidelines

> Edit this file to match your project's conventions.
> The Claude convention reviewer reads this on every PR.

## Always Check

- [ ] New API routes have auth checks
- [ ] Database queries use parameterised values (no raw string interpolation)
- [ ] Client components have "use client" directive when using hooks/state
- [ ] No hardcoded secrets, app names, URLs, or feature flags
- [ ] Error handling on external API calls
- [ ] No console.log left in production code

## Convention Violations (flag as NIT)

- [ ] Component files match naming convention (PascalCase for components)
- [ ] CSS follows project methodology (BEM / Tailwind / CSS Modules)
- [ ] Imports are organised (externals first, then internals)

## Security

- [ ] No secrets in client-side code
- [ ] Auth checks on all protected routes
- [ ] Input validation on user-facing forms
- [ ] SQL injection prevention (parameterised queries)

## Skip During Review

- `*.lock` files (auto-generated)
- `*.snap` files (test snapshots)
- `node_modules/`
- `.next/`

## Project-Specific Rules

Add your own rules here. Examples:

- "Always use the `Button` component from `components/ui/`, never raw `<button>`"
- "API routes must return `{ success: boolean }` shape"
- "Use `config.ts` for app-wide constants, never hardcode"
TEMPLATE
  echo -e "  ${GREEN}+${NC} REVIEW.md — ${YELLOW}edit this to match your project${NC}"
fi

# ── Step 4: .env.local reference ─────────────────────────────
echo ""
echo -e "${BOLD}Step 4/5 — Local Environment Reference${NC}"

ENV_FILE=".env.local"
KEYS_ADDED=0

add_env_key() {
  local key="$1"
  local comment="$2"
  local example="$3"

  if [ -f "$ENV_FILE" ] && grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
    echo -e "  ${GREEN}ok${NC} ${key} already in .env.local"
  elif [ -f "$ENV_FILE" ] && grep -q "^# *${key}=" "$ENV_FILE" 2>/dev/null; then
    echo -e "  ${DIM}~${NC}  ${key} commented out in .env.local (uncomment to use)"
  else
    if [ $KEYS_ADDED -eq 0 ]; then
      if [ -f "$ENV_FILE" ]; then
        echo "" >> "$ENV_FILE"
      fi
      echo "# ── Code Review Pipeline ──────────────────────────" >> "$ENV_FILE"
    fi
    echo "# ${comment}" >> "$ENV_FILE"
    echo "# ${key}=${example}" >> "$ENV_FILE"
    echo -e "  ${GREEN}+${NC} ${key} ${DIM}(commented — fill in your key)${NC}"
    KEYS_ADDED=$((KEYS_ADDED + 1))
  fi
}

add_env_key "ANTHROPIC_API_KEY" "Claude API key — required for convention review + weekly audit" "sk-ant-..."
add_env_key "OPENAI_API_KEY" "OpenAI API key — required for Codex logic review" "sk-..."
add_env_key "SLACK_WEBHOOK_URL" "Slack incoming webhook — optional, for audit notifications" "https://hooks.slack.com/services/..."

if [ $KEYS_ADDED -gt 0 ]; then
  echo ""
  echo -e "  ${DIM}Keys added as comments in .env.local for reference.${NC}"
  echo -e "  ${DIM}CI uses GitHub Secrets (next step), not .env.local.${NC}"
fi

# ── Step 5: GitHub Secrets ───────────────────────────────────
echo ""
echo -e "${BOLD}Step 5/5 — GitHub Secrets${NC}"
echo ""

EXISTING_SECRETS=$(gh secret list --json name -q '.[].name' 2>/dev/null || echo "")
SECRETS_MISSING=""

set_secret_if_missing() {
  local name="$1"
  local desc="$2"
  local required="$3"

  if echo "$EXISTING_SECRETS" | grep -q "^${name}$"; then
    echo -e "  ${GREEN}ok${NC} ${name} already set"
    return
  fi

  local prompt_suffix=""
  if [ "$required" = "optional" ]; then
    prompt_suffix=" (optional)"
  fi

  read -p "  Set ${name}${prompt_suffix}? [y/N] " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "  ${DIM}Paste your key (input hidden):${NC}"
    read -s SECRET_VALUE
    if [ -n "$SECRET_VALUE" ]; then
      echo "$SECRET_VALUE" | gh secret set "$name"
      echo -e "  ${GREEN}ok${NC} ${name} set"
    else
      echo -e "  ${YELLOW}!${NC}  Empty — skipped"
      SECRETS_MISSING="${SECRETS_MISSING}${name} "
    fi
  else
    if [ "$required" = "required" ]; then
      SECRETS_MISSING="${SECRETS_MISSING}${name} "
    fi
  fi
}

set_secret_if_missing "ANTHROPIC_API_KEY" "Claude review + weekly audit" "required"
set_secret_if_missing "OPENAI_API_KEY" "Codex logic review" "required"
set_secret_if_missing "SLACK_WEBHOOK_URL" "Slack audit notifications" "optional"

# ── Summary ──────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Setup complete!                                 ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Files added/updated:${NC}"
echo -e "    ${GREEN}+${NC} .github/workflows/code-review.yml   ${DIM}(3-layer PR review)${NC}"
if [[ ${INSTALL_AUDIT:-Y} =~ ^[Yy]?$ ]]; then
  echo -e "    ${GREEN}+${NC} .github/workflows/weekly-audit.yml  ${DIM}(Monday 2am UTC)${NC}"
fi
echo -e "    ${GREEN}+${NC} REVIEW.md                            ${DIM}(project conventions)${NC}"
echo -e "    ${GREEN}~${NC} .env.local                           ${DIM}(key reference)${NC}"
echo ""
echo -e "  ${BOLD}What happens on every PR:${NC}"
echo -e "    ${DIM}1.${NC} Static checks  ${DIM}(tsc + lint — free)${NC}"
echo -e "    ${DIM}2.${NC} Codex logic    ${DIM}(bugs, security, edge cases — ~\$0.20/PR)${NC}"
echo -e "    ${DIM}3.${NC} Claude review  ${DIM}(conventions from REVIEW.md — ~\$0.35/PR)${NC}"
echo ""
echo -e "  ${BOLD}Checklist:${NC}"
echo -e "    ${CYAN}[ ]${NC} Edit REVIEW.md to match your project conventions"
echo -e "    ${CYAN}[ ]${NC} Commit and push:"
echo -e "        ${DIM}git add .github/ REVIEW.md && git commit -m 'feat: add code review pipeline' && git push${NC}"
echo -e "    ${CYAN}[ ]${NC} Open a test PR to verify the pipeline runs"

if [ -n "$SECRETS_MISSING" ]; then
  echo ""
  echo -e "  ${YELLOW}Missing secrets:${NC} ${SECRETS_MISSING}"
  echo -e "  ${DIM}Set them when ready:${NC}"
  for key in $SECRETS_MISSING; do
    echo -e "    ${DIM}gh secret set ${key}${NC}"
  done
fi

echo ""
