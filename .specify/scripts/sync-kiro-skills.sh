#!/usr/bin/env bash
# Copy .kiro/skills from the speckit worktree into the code checkout.
# KiroCrew rejects symlinked skills (realpath must stay inside <project>/.kiro/skills),
# so .kiro/skills in the checkout must be real files. Re-run after editing skills here.
set -euo pipefail

# cd -P so `../..` walks the real path. A logical cd keeps the `.specify` symlink and resolves
# to <repo> instead of <repo>/.speckit, which would put CODE_ROOT outside the repo.
SPEC_ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"   # the speckit worktree
CODE_ROOT="$(dirname "$SPEC_ROOT")"                                   # checkout that contains it
SRC="$SPEC_ROOT/.kiro/skills"
DEST="$CODE_ROOT/.kiro/skills"

[ -d "$SRC" ] || { echo "missing $SRC" >&2; exit 1; }
[ -d "$CODE_ROOT/.git" ] || [ -f "$CODE_ROOT/.git" ] || { echo "$CODE_ROOT is not a git checkout" >&2; exit 1; }
[ -L "$CODE_ROOT/.kiro" ] && { echo "$CODE_ROOT/.kiro is a symlink; make it a real directory" >&2; exit 1; }

mkdir -p "$CODE_ROOT/.kiro"
rm -rf "$DEST"
cp -R "$SRC" "$DEST"
# Skill directories are created by Spec Kit, so their names are always alnum.
# shellcheck disable=SC2012
echo "synced $(ls "$DEST" | wc -l | tr -d ' ') skills -> $DEST"
