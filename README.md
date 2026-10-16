# spec-kit

A reference setup for keeping [GitHub Spec Kit](https://github.com/github/spec-kit) in any repository without mixing it into the code branches. Spec Kit lives on its own branch, `speckit`, and every checkout links to it.

## Quick Start

Send this one line to your AI tool:

```text
Install the spec-kit: https://github.com/blackened-blue/spec-kit, load the github spec-kit, then set up speckit branch for my repo from scratch.
```

The AI tool follows the [runbook](#runbook-for-the-ai-tool) below. Nothing is pushed until you say so.

Spec Kit is wired only for the harnesses you use. Name them in the line (for example "... for Claude Code and Kiro CLI"). If you do not, the AI tool asks which of these you want before it installs anything:

| Harness | `--harness` value | `specify init --integration` | Wired into the checkout as |
|---|---|---|---|
| Claude Code | `claude-code` | `claude` | `.claude/skills` symlink |
| KiroCrew | `kirocrew` | `claude` (same skills) | `.kiro/skills` copy |
| Kiro CLI | `kiro-cli` | `kiro-cli` | `.kiro/prompts` copy (untested) |

## What you get

| Path in your repo | Lives on | What it is |
|---|---|---|
| `speckit` branch | git | Orphan branch holding only Spec Kit material |
| `.speckit/` | worktree of `speckit` | Where you read and edit Spec Kit files |
| `.claude/skills` | symlink to `.speckit/.claude/skills` | The `speckit-*` skills for Claude Code (`claude-code` only) |
| `.kiro/skills` | **copy** of `.speckit/.kiro/skills` | The same skills for KiroCrew (`kirocrew` only) |
| `.kiro/prompts` | **copy** of `.speckit/.kiro/prompts` | The `/speckit.*` prompts for Kiro CLI (`kiro-cli` only) |
| `.specify` | symlink to `.speckit/.specify` | Spec Kit templates, scripts and constitution |
| `specs` | symlink to `.speckit/specs` | Feature specs, plans and tasks that Spec Kit writes to `<repo>/specs/` |
| `scripts/setup-speckit.sh` | code branch | One command that rebuilds all of the above in a fresh clone |
| `.claude/settings.json` | code branch | `SessionStart` hook that runs the setup script when `.speckit/` is missing (Claude Code) |
| `.kiro/steering/speckit-setup.md` | code branch | Steering rule that tells KiroCrew to run the same script |
| `<git-dir>/speckit-harness` | your machine only | The harnesses you chose on this machine; never committed |

The links and copies are git-ignored on the code branch, so the code branch never carries Spec Kit files.

## Requirements

- `git` 2.42 or newer (`git worktree add --orphan`)
- [`uv`](https://docs.astral.sh/uv/) to install the `specify` CLI
- Tested with `specify` 1.1.3 and the `claude` integration

## Runbook for the AI tool

Run from the root of the target repo, on the branch that holds its code. Stop and ask the user if a step does not match what is described. Do not push anything until the user asks; when asked, push by explicit branch name (`git push origin speckit`), never to a protected branch.

### 0. Check preconditions

```bash
git rev-parse --show-toplevel          # must be the repo root
git --version                          # 2.42 or newer
git show-ref --verify --quiet refs/heads/speckit && echo "speckit exists"
git ls-remote --exit-code --heads origin speckit && echo "speckit exists on origin"
[ -e .speckit ] && echo ".speckit exists"
```

If `speckit` or `.speckit` already exists, this repo is already set up. Use [Joining a repo that is already set up](#joining-a-repo-that-is-already-set-up) instead.

### 0b. Choose harnesses

If the user did not name the harnesses to set up (`claude-code`, `kirocrew`, `kiro-cli`, any subset), ask before going on. Set up only what they choose. The steps below say which parts belong to which harness.

### 1. Install the Spec Kit CLI

```bash
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
specify --version
```

### 2. Fetch the reference files

The files below are copied from this repo, so fetch it once into a temp directory. `--no-single-branch` is required to see `origin/speckit`.

```bash
SRC="$(mktemp -d)/spec-kit"
git clone --no-single-branch --depth 1 -b develop https://github.com/blackened-blue/spec-kit.git "$SRC"
```

### 3. Build the `speckit` branch

```bash
git worktree add --orphan -b speckit .speckit
cd .speckit
specify init --here --force --non-interactive --integration claude   # skills for claude-code and kirocrew
# Only if the user chose kiro-cli:
# specify integration install kiro-cli                               # adds .kiro/prompts

mkdir -p .kiro .specify/scripts specs
# Only if the user chose kirocrew: it reads skills from .kiro/skills, so mirror the Claude skills.
cp -R .claude/skills .kiro/skills
touch specs/.gitkeep    # Spec Kit writes feature specs to <repo>/specs/, which links here

git -C "$SRC" show origin/speckit:.specify/scripts/sync-kiro-skills.sh > .specify/scripts/sync-kiro-skills.sh
chmod +x .specify/scripts/sync-kiro-skills.sh
git -C "$SRC" show origin/speckit:.gitignore > .gitignore

git add -A
git commit -m "Add Spec Kit"
cd ..
```

`.gitignore` on this branch keeps `.claude/settings.local.json` out of it. Keep the branch free of everything except Spec Kit material (no LICENSE, no README).

### 4. Wire up the code branch

```bash
mkdir -p scripts
cp "$SRC/scripts/setup-speckit.sh" scripts/
chmod +x scripts/setup-speckit.sh
```

Per chosen harness:

- `claude-code`: add the `SessionStart` hook from `$SRC/.claude/settings.json` to `.claude/settings.json`. If the file does not exist, copy it. If it does, merge the `hooks.SessionStart` entry and keep the existing settings.
- `kirocrew`: `mkdir -p .kiro/steering && cp "$SRC/.kiro/steering/speckit-setup.md" .kiro/steering/`
- `kiro-cli`: nothing to copy; the script wires `.kiro/prompts`.

Append these lines to `.gitignore`, keeping only the harness lines the user chose:

```text
# Spec Kit lives on branch speckit (worktree at .speckit/)
/.speckit/
/.specify
/specs
/.claude/skills     # claude-code
/.kiro/skills       # kirocrew
/.kiro/prompts      # kiro-cli
```

Then create the links and copies for the chosen harnesses, and commit:

```bash
scripts/setup-speckit.sh --harness claude-code,kirocrew    # list only the chosen ones
git add scripts/setup-speckit.sh .gitignore                # plus .claude/settings.json and/or .kiro/steering/speckit-setup.md, whichever you added
git commit -m "Add Spec Kit setup"
```

### 5. Verify

```bash
git worktree list                       # shows .speckit on branch speckit
git status --short                      # clean
ls .claude/skills .kiro/skills          # 10 speckit-* skills each (whichever harnesses you chose)
ls -ld specs                            # symlink to .speckit/specs
git -C .speckit log --oneline           # the "Add Spec Kit" commit
```

### 6. Report to the user

Say what was created, that nothing was pushed, that specs are committed with `git -C .speckit` (see [Committing specs](#committing-specs)), and that the `speckit-*` skills appear from the **next** session (see [Notes](#notes)). Offer to push `speckit` and the code branch.

## Joining a repo that is already set up

After cloning a repo that has the `speckit` branch:

```bash
scripts/setup-speckit.sh --harness claude-code,kirocrew    # only the harnesses you use on this machine
```

The choice is saved in `<git-dir>/speckit-harness` on your machine and is not committed, so each person picks their own. Later runs add to it. Claude Code and KiroCrew run the script for you at the start of the first session (the hook passes `--harness claude-code`, the steering file passes `--harness kirocrew`). The script is safe to re-run. If `.speckit/` already exists, the hook and the steering file do nothing, so run the script yourself to add another harness.

After editing a skill under `.speckit/.kiro/skills`, copy it into the checkout again:

```bash
.specify/scripts/sync-kiro-skills.sh
```

## Committing specs

Specs and every other Spec Kit change are written into `.speckit/`, so they are **not** tracked by the code branch. `git status` in the repo root stays clean while `git -C .speckit status` shows the new files. Commit them on `speckit`:

```bash
git -C .speckit add -A
git -C .speckit commit -m "Add spec for <feature>"
git push origin speckit        # only when you want to publish it
```

An AI tool that runs a Spec Kit command (`/speckit-specify`, `/speckit-plan`, `/speckit-tasks`, ...) must commit in `.speckit/` afterwards, because committing in the repo root records nothing.

## Notes

- **Skills appear from the second session.** Claude Code scans skills before its `SessionStart` hook runs, so on a fresh clone the first session installs them and the next session sees them. Tested with `claude -p`: the first run listed no `speckit-*` skills, the second listed all 10.
- **Why `.kiro/skills` is a copy.** KiroCrew resolves each skill's real path and rejects any that lands outside `<project>/.kiro/skills`, so a symlink into `.speckit/` does not load. `.claude/skills` and `.specify` work as symlinks. KiroCrew also needs the project to be trusted in its dashboard before it loads project skills.
- **Kiro CLI is untested.** `.kiro/prompts` is a copy like `.kiro/skills`, but nobody has checked whether Kiro CLI accepts a symlink there or loads the copy. Re-run the script after editing prompts under `.speckit/.kiro/prompts`.
- **Why only `skills` is a symlink inside `.claude/` and `.kiro/`.** Making the whole directory a symlink stopped skills from loading, and a real directory leaves room for the code branch to track `.claude/settings.json` and `.kiro/steering/`.
- **`.claude/settings.local.json`** is personal. It is ignored on the `speckit` branch.
