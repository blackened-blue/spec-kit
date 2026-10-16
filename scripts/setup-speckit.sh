#!/usr/bin/env bash
# Set up Spec Kit in this checkout. Spec Kit lives on branch `speckit`, not on the code branches.
# Creates the worktree .speckit/, links .specify and specs into it, then wires only the harnesses
# you choose:  scripts/setup-speckit.sh --harness claude-code,kirocrew,kiro-cli
#   claude-code  symlink .claude/skills
#   kirocrew     copy .kiro/skills (KiroCrew rejects symlinked skills)
#   kiro-cli     copy .kiro/prompts (needs the kiro-cli integration on branch speckit; untested)
# The choice is remembered per machine in <git-dir>/speckit-harness (never committed); later runs
# add to it. Safe to re-run.
set -euo pipefail

BRANCH=speckit
cd "$(git rev-parse --show-toplevel)"

CHOICE_FILE="$(git rev-parse --git-common-dir)/speckit-harness"
requested=""
while [ $# -gt 0 ]; do
  case "$1" in
    --harness) requested="${2:?--harness needs a value}"; shift 2 ;;
    --harness=*) requested="${1#*=}"; shift ;;
    *) echo "usage: $0 --harness claude-code,kirocrew,kiro-cli" >&2; exit 1 ;;
  esac
done
requested="${requested//,/ }"
for h in $requested; do
  case "$h" in claude-code|kirocrew|kiro-cli) ;; *) echo "unknown harness: $h" >&2; exit 1 ;; esac
done
harnesses="$(printf '%s\n' $requested $(cat "$CHOICE_FILE" 2>/dev/null) | sort -u | tr '\n' ' ')"
[ -n "${harnesses// /}" ] || { echo "no harness chosen; run: $0 --harness claude-code,kirocrew,kiro-cli (any subset)" >&2; exit 1; }
printf '%s\n' $harnesses > "$CHOICE_FILE"

if [ ! -e .speckit ]; then
  if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git worktree add .speckit "$BRANCH"
  else
    git fetch origin "$BRANCH" || { echo "branch $BRANCH not found locally or on origin" >&2; exit 1; }
    git worktree add --track -b "$BRANCH" .speckit "origin/$BRANCH"
  fi
fi

link() {  # link <target relative to link dir> <link path>
  if [ -e "$2" ] && [ ! -L "$2" ]; then echo "$2 exists and is not a symlink; move it away first" >&2; exit 1; fi
  mkdir -p "$(dirname "$2")"
  ln -sfn "$1" "$2"
}
mkdir -p .speckit/specs   # feature specs are written to <root>/specs; keep them on the speckit branch
link .speckit/.specify .specify
link .speckit/specs specs

for h in $harnesses; do
  case "$h" in
    claude-code) link ../.speckit/.claude/skills .claude/skills ;;
    kirocrew) .speckit/.specify/scripts/sync-kiro-skills.sh ;;
    kiro-cli)
      [ -d .speckit/.kiro/prompts ] || { echo "branch $BRANCH has no .kiro/prompts; run 'specify integration install kiro-cli' there first" >&2; exit 1; }
      mkdir -p .kiro && rm -rf .kiro/prompts && cp -R .speckit/.kiro/prompts .kiro/prompts ;;
  esac
done
echo "Spec Kit ready: .speckit (branch $BRANCH), .specify, specs, harnesses: $harnesses"
