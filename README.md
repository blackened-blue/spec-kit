# spec-kit

A reference setup for keeping [GitHub Spec Kit](https://github.com/github/spec-kit) in any repository without mixing it into the code branches. You choose one of two modes:

| Mode | Where Spec Kit files live | Shared with the team | Survives a new clone |
|---|---|---|---|
| **A. Separate branch** | On branch `speckit`, linked into every checkout | Yes, push `speckit` | Yes, one command rebuilds the links |
| **B. Local only** | Plain files in your working tree, hidden from git | No | No, set up again on the new clone |

Mode B never commits anything and creates no branch. Specs, plans and the constitution exist only on your machine, so they have no git history and are lost if you delete the folder or switch machines. Pick it when you want Spec Kit without any trace in the repo.

## Quick Start

Send this one line to your AI tool:

```text
Install the spec-kit: https://github.com/blackened-blue/spec-kit, load the github spec-kit, then set up speckit branch for my repo from scratch.
```

For mode B, say so in the line, for example: "... then set up Spec Kit for my repo **without a separate branch** (local only)." If you do not say which mode, the AI tool asks before it installs anything.

The AI tool follows the [runbook](#runbook-for-the-ai-tool) below. Nothing is pushed until you say so.

Spec Kit is wired only for the harnesses you use. By default the AI tool wires the harness it is running in, with no question. Name others in the line to add them (for example "... for Claude Code and Kiro CLI"). It asks only when it cannot tell which harness it is running in:

| Harness | `--harness` value | `specify init --integration` | Wired into the checkout as |
|---|---|---|---|
| Claude Code | `claude-code` | `claude` | `.claude/skills` symlink |
| KiroCrew | `kirocrew` | `claude` (same skills) | `.kiro/skills` copy |
| Kiro CLI | `kiro-cli` | `kiro-cli` | `.kiro/prompts` copy (untested) |

## What you get (mode A)

For mode B see [Mode B: local only](#mode-b-local-only).

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

Run from the root of the target repo, on the branch that holds its code (a new empty repo is fine, see step 0). Stop and ask the user if a step does not match what is described. Do not push anything until the user asks; when asked, push by explicit branch name (`git push origin speckit`), never to a protected branch.

### 0. Check preconditions

If the current folder is not inside a git repo (`git rev-parse --show-toplevel` fails), do not ask: run `git init` in it, tell the user you did, and carry on. `git init` only creates a local `.git` folder; there is no remote and nothing is pushed. Do this only for the folder the user opened, never for a parent or a home folder. Mode A works on an empty repo with no commits (checked: `git worktree add --orphan -b speckit .speckit` succeeds). If the folder is inside a repo, use that repo's root and do not init.

```bash
git rev-parse --show-toplevel          # must be the repo root
git --version                          # 2.42 or newer
git show-ref --verify --quiet refs/heads/speckit && echo "speckit exists"
git ls-remote --exit-code --heads origin speckit && echo "speckit exists on origin"
[ -e .speckit ] && echo ".speckit exists"
```

If `speckit` or `.speckit` already exists, this repo is already set up. Use [Joining a repo that is already set up](#joining-a-repo-that-is-already-set-up) instead.

### 0b. Choose mode and harnesses

If the user did not say whether they want a separate `speckit` branch (mode A) or local only (mode B), ask first. For mode B, skip the rest of this runbook and follow [Mode B: local only](#mode-b-local-only).

Pick the harnesses without asking, in this order:

1. The ones the user named (`claude-code`, `kirocrew`, `kiro-cli`, any subset). Add the harness you are running in too, unless the user said otherwise.
2. Otherwise the harness you are running in: Claude Code is `claude-code`, KiroCrew is `kirocrew`, Kiro CLI is `kiro-cli`.
3. Only if you cannot tell which harness you are running in, ask the user which of the three they want.

Say which harnesses you picked in your report, and that more can be added later by re-running the setup script with `--harness` (`-Harness` on Windows). Set up only the picked ones. The steps below say which parts belong to which harness.

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
# claude-code
/.claude/skills
# kirocrew
/.kiro/skills
# kiro-cli
/.kiro/prompts
```

Keep each comment on its own line: a `#` after a pattern is part of the pattern.

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

## Mode B: local only

Spec Kit is installed straight into the working tree and hidden from git. No branch, no worktree, no symlinks, no hook, no steering rule and no setup script are created. Nothing in the repo changes, so there is nothing to commit or push.

Run from the root of the target repo. Do not push anything.

```bash
git rev-parse --show-toplevel                      # must be the repo root
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
specify --version

specify init --here --force --non-interactive --integration claude    # skills for claude-code and kirocrew
# Only if the user chose kiro-cli:
# specify integration install kiro-cli                                # adds .kiro/prompts
# Only if the user chose kirocrew: it reads skills from .kiro/skills, so copy the Claude skills.
# mkdir -p .kiro && cp -R .claude/skills .kiro/skills
```

Hide the files with the repo-local exclude file, which is not tracked and not shared. Keep only the lines for the harnesses the user chose:

```bash
cat >> "$(git rev-parse --git-path info/exclude)" <<'EOF'
# Spec Kit, local only
/.specify/
/specs/
# claude-code
/.claude/skills/
# kirocrew
/.kiro/skills/
# kiro-cli
/.kiro/prompts/
EOF
git status --short                                 # must show nothing for these paths
```

`specify init` can rewrite an existing tracked `.claude/settings.json` (we saw the same JSON reformatted, with its contents kept). If `git status` shows it as modified, review the change and undo it with `git checkout -- .claude/settings.json` unless the user wants it.

Say what was created, that nothing was committed or pushed, that the files exist only on this machine, and that the `speckit-*` skills appear from the next session. A fresh clone gets none of this, so run the commands above again there.

### Moving from mode B to mode A

This path is untested. Create the branch, move the files into the worktree, drop the exclude lines, then continue with runbook steps 2 to 4 (skip the `specify init` lines, the files are already there):

```bash
git worktree add --orphan -b speckit .speckit
mkdir -p .speckit/.claude .speckit/.kiro
mv .specify .speckit/.specify
[ -d specs ] && mv specs .speckit/specs
mv .claude/skills .speckit/.claude/skills     # claude-code
mv .kiro/skills .speckit/.kiro/skills         # kirocrew
mv .kiro/prompts .speckit/.kiro/prompts       # kiro-cli
# then remove the "Spec Kit, local only" block from $(git rev-parse --git-path info/exclude)
```

## Windows (PowerShell)

Everything here is PowerShell 5.1 or newer, no Git Bash or WSL. **Untested on Windows**; only a macOS check of the bash twin exists. Requirements: `git` 2.42+, `uv`, and for mode A real symlinks, which need **Developer Mode** (Settings > System > For developers) or an administrator shell. `scripts\setup-speckit.ps1` tests this first and stops without changing anything if symlinks are not allowed. If PowerShell blocks the script, run it as `powershell -ExecutionPolicy Bypass -File scripts\setup-speckit.ps1 -Harness claude-code`.

### Mode A (separate branch)

Run from the repo root, on the code branch. The AI tool follows the same order as the bash runbook, including running `git init` when the folder is not a repo yet; do not push until the user asks.

```powershell
# 0. preconditions
git rev-parse --show-toplevel
git --version                                                  # 2.42 or newer
git show-ref --verify --quiet refs/heads/speckit; if ($LASTEXITCODE -eq 0) { "speckit exists" }
git ls-remote --exit-code --heads origin speckit; if ($LASTEXITCODE -eq 0) { "speckit exists on origin" }
if (Test-Path .speckit) { ".speckit exists" }

# 1. install the CLI, 2. fetch the reference files
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
specify --version
$SRC = Join-Path ([IO.Path]::GetTempPath()) "spec-kit-$([guid]::NewGuid())"
git clone --no-single-branch --depth 1 -b develop https://github.com/blackened-blue/spec-kit.git $SRC

# 3. build the speckit branch
git worktree add --orphan -b speckit .speckit
Set-Location .speckit
specify init --here --force --non-interactive --integration claude   # skills for claude-code and kirocrew
# Only if the user chose kiro-cli:
# specify integration install kiro-cli
New-Item -ItemType Directory -Force .kiro, .specify\scripts, specs | Out-Null
# Only if the user chose kirocrew:
Copy-Item -Recurse .claude\skills .kiro\skills
New-Item -ItemType File -Force specs\.gitkeep | Out-Null
# cmd keeps the bytes (and LF line endings) exactly as git prints them
cmd /c "git -C `"$SRC`" show origin/speckit:.specify/scripts/sync-kiro-skills.sh > .specify\scripts\sync-kiro-skills.sh"
cmd /c "git -C `"$SRC`" show origin/speckit:.gitignore > .gitignore"
git add -A
git commit -m "Add Spec Kit"
Set-Location ..

# 4. wire the code branch
New-Item -ItemType Directory -Force scripts | Out-Null
Copy-Item "$SRC\scripts\setup-speckit.ps1", "$SRC\scripts\setup-speckit.sh" scripts\   # keep the .sh for macOS and Linux teammates
```

Per chosen harness, as in the bash runbook: for `claude-code` merge the `hooks.SessionStart` entry from `$SRC\.claude\settings.json` into `.claude\settings.json` (it is the bash hook, which skips itself on Windows), then add the Windows hook to `.claude\settings.local.json` (see below); for `kirocrew` copy `$SRC\.kiro\steering\speckit-setup.md` into `.kiro\steering\`; `kiro-cli` needs nothing. Then add the ignore lines, keeping only the chosen harnesses, and create the links:

```powershell
$lines = '# Spec Kit lives on branch speckit (worktree at .speckit/)', '/.speckit/', '/.specify', '/specs',
         '# claude-code', '/.claude/skills', '# kirocrew', '/.kiro/skills', '# kiro-cli', '/.kiro/prompts'   # drop the pairs you do not use
[IO.File]::AppendAllText((Join-Path (Get-Location) '.gitignore'), ($lines -join "`n") + "`n")   # LF line endings
scripts\setup-speckit.ps1 -Harness claude-code,kirocrew        # list only the chosen ones
git add scripts .gitignore                                     # plus .claude\settings.json and/or .kiro\steering\speckit-setup.md
git commit -m "Add Spec Kit setup"

# 5. verify
git worktree list                                              # shows .speckit on branch speckit
git status --short                                             # clean
Get-ChildItem .claude\skills, .kiro\skills                     # 10 speckit-* skills each (chosen harnesses)
(Get-Item specs).LinkType                                      # SymbolicLink
git -C .speckit log --oneline
```

Joining a repo that is already set up: `scripts\setup-speckit.ps1 -Harness claude-code,kirocrew`. The choice is saved in `<git-dir>\speckit-harness` and later runs add to it. For Claude Code to run the script at session start on Windows, create `.claude\settings.local.json` (personal, ignored by git; if it already exists, merge the `hooks.SessionStart` entry into it) with:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "shell": "powershell",
            "command": "Set-Location $env:CLAUDE_PROJECT_DIR; if (-not (Test-Path .speckit)) { powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\setup-speckit.ps1 -Harness claude-code }"
          }
        ]
      }
    ]
  }
}
```

Each Windows user does this once per clone, because the file is not committed. The KiroCrew steering rule tells it to run the `.ps1` on Windows. After editing a skill under `.speckit\.kiro\skills`, re-run the script to copy it into the checkout. Committing specs is the same `git -C .speckit add -A` and `git -C .speckit commit` as in [Committing specs](#committing-specs).

### Mode B (local only)

```powershell
git rev-parse --show-toplevel
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
specify init --here --force --non-interactive --integration claude
# Only if the user chose kiro-cli:
# specify integration install kiro-cli
# Only if the user chose kirocrew:
# New-Item -ItemType Directory -Force .kiro | Out-Null; Copy-Item -Recurse .claude\skills .kiro\skills

$exclude = Join-Path (Get-Location) (git rev-parse --git-path info/exclude)
$lines = '# Spec Kit, local only', '/.specify/', '/specs/',
         '# claude-code', '/.claude/skills/', '# kirocrew', '/.kiro/skills/', '# kiro-cli', '/.kiro/prompts/'   # drop the pairs you do not use
[IO.File]::AppendAllText($exclude, ($lines -join "`n") + "`n")
git status --short                                             # must show nothing for these paths
```

The notes in [Mode B: local only](#mode-b-local-only) about `.claude/settings.json` apply too (`git checkout -- .claude/settings.json`). To move to mode A: `git worktree add --orphan -b speckit .speckit`, then `Move-Item` each of `.specify`, `specs`, `.claude\skills`, `.kiro\skills`, `.kiro\prompts` (the ones that exist) into `.speckit\` at the same relative path, remove the "Spec Kit, local only" block from the exclude file, and continue with steps 3 and 4 above. This move is untested.

## Notes

- **Skills appear from the second session.** Claude Code scans skills before its `SessionStart` hook runs, so on a fresh clone the first session installs them and the next session sees them. Tested with `claude -p`: the first run listed no `speckit-*` skills, the second listed all 10.
- **Why `.kiro/skills` is a copy.** KiroCrew resolves each skill's real path and rejects any that lands outside `<project>/.kiro/skills`, so a symlink into `.speckit/` does not load. `.claude/skills` and `.specify` work as symlinks. KiroCrew also needs the project to be trusted in its dashboard before it loads project skills.
- **Kiro CLI is untested.** `.kiro/prompts` is a copy like `.kiro/skills`, but nobody has checked whether Kiro CLI accepts a symlink there or loads the copy. Re-run the script after editing prompts under `.speckit/.kiro/prompts`.
- **Why only `skills` is a symlink inside `.claude/` and `.kiro/`.** Making the whole directory a symlink stopped skills from loading, and a real directory leaves room for the code branch to track `.claude/settings.json` and `.kiro/steering/`.
- **Platforms.** Only macOS is tested. macOS and Linux use the bash script; Windows uses [PowerShell](#windows-powershell) and `scripts\setup-speckit.ps1`, which is untested. Mode A needs real symlinks, so both scripts create a test symlink in the git dir first and stop without changing anything if that fails (on Windows: Developer Mode or an administrator shell).
- **Claude Code hooks on Windows.** The committed `.claude/settings.json` has only the bash `SessionStart` hook, and it does nothing when `$OS` is `Windows_NT`. The PowerShell hook lives in each Windows user's own `.claude/settings.local.json` (git-ignored), so macOS and Linux never see it; a PowerShell entry in the committed file made macOS print `Failed to run: Hook "if ($env:OS ...` at every session start (checked with `claude -p`). Reports from other users say hooks on Windows can still run through Git Bash despite `"shell": "powershell"`, and the field is not documented officially, so if the hook never fires run the `.ps1` by hand.
- **`.claude/settings.local.json`** is personal. It is ignored on the `speckit` branch.
