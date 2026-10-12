#!/usr/bin/env bash
# Set up Spec Kit in this checkout. Spec Kit lives on branch `speckit`, not on the code branches.
# Creates the worktree .speckit/, links .claude/skills, .specify and specs into it, and copies
# .kiro/skills (KiroCrew rejects symlinked skills). Safe to re-run.
set -euo pipefail

BRANCH=speckit
cd "$(git rev-parse --show-toplevel)"

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
link ../.speckit/.claude/skills .claude/skills
link .speckit/.specify .specify
link .speckit/specs specs

.speckit/.specify/scripts/sync-kiro-skills.sh
echo "Spec Kit ready: .speckit (branch $BRANCH), .claude/skills, .specify, specs, .kiro/skills"
