#!/usr/bin/env bash
#
# validate.sh — lightweight validator for the skills in this repo.
#
# For every skills/<name>/SKILL.md it checks:
#   - the file has YAML frontmatter (opens with '---')
#   - frontmatter declares a non-empty `name` and `description`
#   - `name` matches the parent directory name
#   - `name` is lowercase letters/digits/hyphens, no leading/trailing/double hyphen
#
# Exit code is non-zero if any skill fails, so it doubles as a CI gate.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$ROOT/skills"

fail=0

err() { echo "  ✗ $1" >&2; fail=1; }

if [[ ! -d "$SKILLS_DIR" ]]; then
  echo "error: no skills/ directory found at $SKILLS_DIR" >&2
  exit 2
fi

shopt -s nullglob
found=0
for dir in "$SKILLS_DIR"/*/; do
  found=1
  name_dir="$(basename "$dir")"
  skill_md="$dir/SKILL.md"
  echo "checking $name_dir"

  if [[ ! -f "$skill_md" ]]; then
    err "missing SKILL.md"
    continue
  fi

  if [[ "$(head -n1 "$skill_md")" != "---" ]]; then
    err "SKILL.md does not start with YAML frontmatter ('---')"
    continue
  fi

  # Extract the frontmatter block (between the first two '---' lines).
  fm="$(awk 'NR==1{next} /^---[[:space:]]*$/{exit} {print}' "$skill_md")"

  name_val="$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -n1 | tr -d '"'"'"' \r')"
  desc_val="$(printf '%s\n' "$fm" | sed -n 's/^description:[[:space:]]*//p' | head -n1)"

  [[ -n "$name_val" ]] || err "frontmatter missing 'name'"
  [[ -n "$desc_val" ]] || err "frontmatter missing 'description'"

  if [[ -n "$name_val" && "$name_val" != "$name_dir" ]]; then
    err "name '$name_val' does not match directory '$name_dir'"
  fi

  if [[ -n "$name_val" ]] && ! printf '%s' "$name_val" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'; then
    err "name '$name_val' is not lowercase alphanumeric with single hyphens"
  fi
done

if [[ "$found" -eq 0 ]]; then
  echo "error: no skills found under $SKILLS_DIR" >&2
  exit 2
fi

if [[ "$fail" -ne 0 ]]; then
  echo "validation FAILED" >&2
  exit 1
fi

echo "all skills valid"
