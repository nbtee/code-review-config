#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# Code Review Pipeline — One-Command Setup
#
# Run this in any repo to add multi-model code review:
#   curl -sL https://raw.githubusercontent.com/nbtee/code-review-config/main/setup.sh | bash
#   — or —
#   bash setup.sh
#
# Prerequisites:
#   - gh CLI installed and authenticated
#   - Repository has GitHub Actions enabled
# ──────────────────────────────────────────────────────────────

set -euo pipefail

REPO_OWNER="nbtee"
CONFIG_REPO="code-review-config"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/${REPO_OWNER}/${CONFIG_REPO}/${BRANCH}"

echo "╔══════════════════════════════════════════════╗"
echo "║  Code Review Pipeline — Setup                ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# Check prerequisites
if ! command -v gh &> /dev/null; then
  echo "❌ gh CLI not found. Install: https://cli.github.com/"
  exit 1
fi

if ! gh auth status &> /dev/null; then
  echo "❌ gh not authenticated. Run: gh auth login"
  exit 1
fi

# Detect repo
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || true)
if [ -z "$REPO" ]; then
  echo "❌ Not in a GitHub repository. Run this from your repo root."
  exit 1
fi

echo "📁 Repository: $REPO"
echo ""

# Create workflow directory
mkdir -p .github/workflows

# ── Step 1: Install PR review workflow ──────────────────────
echo "📋 Installing PR review workflow..."
cat > .github/workflows/code-review.yml << 'WORKFLOW'
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
echo "  ✅ .github/workflows/code-review.yml"

# ── Step 2: Install weekly audit workflow ───────────────────
read -p "📅 Install weekly audit (Monday 2am UTC)? [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  cat > .github/workflows/weekly-audit.yml << 'WORKFLOW'
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
  echo "  ✅ .github/workflows/weekly-audit.yml"
fi

# ── Step 3: Create REVIEW.md if missing ─────────────────────
if [ ! -f "REVIEW.md" ]; then
  read -p "📝 Create REVIEW.md template? [y/N] " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    curl -sL "${RAW_BASE}/REVIEW.md.template" > REVIEW.md 2>/dev/null || cat > REVIEW.md << 'TEMPLATE'
# Code Review Guidelines

## Always Check

- New API routes have auth checks
- Database queries use parameterised values
- Client components have "use client" directive when using hooks/state
- No hardcoded app name, URLs, or feature flags

## Convention Violations (flag as NIT)

- Add your project-specific conventions here

## Skip

- Add paths to skip during review
TEMPLATE
    echo "  ✅ REVIEW.md (edit to match your project conventions)"
  fi
fi

# ── Step 4: Set secrets ─────────────────────────────────────
echo ""
echo "🔑 Setting up secrets..."

# Check if secrets exist
HAS_ANTHROPIC=$(gh secret list --json name -q '.[].name' 2>/dev/null | grep -c "ANTHROPIC_API_KEY" || true)
HAS_OPENAI=$(gh secret list --json name -q '.[].name' 2>/dev/null | grep -c "OPENAI_API_KEY" || true)

if [ "$HAS_ANTHROPIC" -eq 0 ]; then
  read -p "  Set ANTHROPIC_API_KEY? (required for Claude review) [y/N] " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "  Paste your Anthropic API key (input hidden):"
    read -s ANTHROPIC_KEY
    echo "$ANTHROPIC_KEY" | gh secret set ANTHROPIC_API_KEY
    echo "  ✅ ANTHROPIC_API_KEY set"
  fi
else
  echo "  ✅ ANTHROPIC_API_KEY already set"
fi

if [ "$HAS_OPENAI" -eq 0 ]; then
  read -p "  Set OPENAI_API_KEY? (required for Codex review) [y/N] " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "  Paste your OpenAI API key (input hidden):"
    read -s OPENAI_KEY
    echo "$OPENAI_KEY" | gh secret set OPENAI_API_KEY
    echo "  ✅ OPENAI_API_KEY set"
  fi
else
  echo "  ✅ OPENAI_API_KEY already set"
fi

# ── Done ────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  ✅ Setup complete!                          ║"
echo "║                                              ║"
echo "║  Next steps:                                 ║"
echo "║  1. Edit REVIEW.md for your conventions      ║"
echo "║  2. Commit and push the workflow files        ║"
echo "║  3. Open a PR to test the review pipeline     ║"
echo "╚══════════════════════════════════════════════╝"
