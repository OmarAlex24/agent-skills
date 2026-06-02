#!/usr/bin/env bash
#
# delegate.sh — hand an agreed plan to an external coding agent (Codex) running
# non-interactively, block until it finishes, and leave the changes in the
# working tree for review.
#
# This wraps `codex exec` with the flags that make a delegated run robust:
# reads the plan from a file via stdin, pins the working dir, runs unattended
# inside the workspace sandbox, and never pauses for approval (which would hang
# a non-interactive run). It captures both the JSONL event stream and Codex's
# final summary so the caller can inspect what happened.
#
# The base commit is recorded BEFORE delegating so the reviewer can diff exactly
# what the external agent changed.
#
# Usage:
#   delegate.sh <plan-file> [repo-root]
#
#   <plan-file>   Path to the markdown plan/prompt to hand to the agent.
#   [repo-root]   Repo to operate in. Defaults to the current git toplevel.
#
# Outputs (in /tmp, agent-agnostic scratch):
#   /tmp/delegate-base-ref.txt   commit the run started from (diff against this)
#   /tmp/delegate-events.jsonl   streamed events from the run
#   /tmp/delegate-result.txt     the agent's final natural-language summary
#
# Exit code mirrors the agent's: non-zero means it failed or couldn't finish —
# inspect the outputs and do NOT treat the result as a clean implementation.

set -euo pipefail

PLAN_FILE="${1:?usage: delegate.sh <plan-file> [repo-root]}"
REPO_ROOT="${2:-$(git rev-parse --show-toplevel)}"

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "error: plan file not found: $PLAN_FILE" >&2
  exit 2
fi

# Fail fast if the external agent isn't ready, with an actionable message.
if ! command -v codex >/dev/null 2>&1; then
  echo "error: 'codex' not found. Install with: npm install -g @openai/codex" >&2
  exit 3
fi
if ! codex login status >/dev/null 2>&1; then
  echo "error: codex is not authenticated. Run: codex login" >&2
  exit 3
fi

# Record the starting point so the review step can isolate the agent's changes.
git -C "$REPO_ROOT" rev-parse HEAD > /tmp/delegate-base-ref.txt
echo "base ref: $(cat /tmp/delegate-base-ref.txt)"

# Warn (don't block) on a dirty tree — the caller should note pre-existing
# changes so they aren't later attributed to the agent.
if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
  echo "warning: working tree is dirty before delegating; pre-existing changes:" >&2
  git -C "$REPO_ROOT" status --porcelain >&2
fi

echo "delegating to codex (this blocks until it finishes)..."

# The actual handoff. `-` reads the plan from stdin. The run is synchronous:
# this line returns only when Codex has finished or errored.
set +e
codex exec - \
  --cd "$REPO_ROOT" \
  --sandbox workspace-write \
  --ask-for-approval never \
  --json \
  --output-last-message /tmp/delegate-result.txt \
  < "$PLAN_FILE" \
  | tee /tmp/delegate-events.jsonl
CODEX_EXIT=${PIPESTATUS[0]}
set -e

echo "---"
if [[ "$CODEX_EXIT" -ne 0 ]]; then
  echo "codex exited non-zero ($CODEX_EXIT) — the run did not finish cleanly." >&2
  echo "inspect /tmp/delegate-events.jsonl and /tmp/delegate-result.txt before reviewing." >&2
  exit "$CODEX_EXIT"
fi

echo "codex finished. Changes since base:"
git -C "$REPO_ROOT" diff --stat "$(cat /tmp/delegate-base-ref.txt)"
echo "---"
echo "agent summary:"
cat /tmp/delegate-result.txt
echo
echo "Next: review the diff against $(cat /tmp/delegate-base-ref.txt) using the pr-review-orchestrator skill."
