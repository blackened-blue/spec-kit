# Set up Spec Kit in this checkout on Windows. PowerShell twin of setup-speckit.sh (PowerShell 5.1+).
# Spec Kit lives on branch `speckit`, not on the code branches. Creates the worktree .speckit/, links
# .specify and specs into it, then wires only the harnesses you choose:
#   scripts\setup-speckit.ps1 -Harness claude-code,kirocrew,kiro-cli
#   claude-code  symlink .claude\skills
#   kirocrew     copy .kiro\skills (KiroCrew rejects symlinked skills)
#   kiro-cli     copy .kiro\prompts (needs the kiro-cli integration on branch speckit; untested)
# Needs real symlinks: turn on Developer Mode (Settings > System > For developers) or run as admin.
# The choice is remembered per machine in <git-dir>\speckit-harness (never committed); later runs
# add to it. Safe to re-run.
param([string[]]$Harness = @())

$ErrorActionPreference = 'Stop'
$Branch = 'speckit'

function Invoke-Git {
  $out = & git @args
  if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed" }
  $out
}

function New-Link {  # New-Link <link path> <target path>
  param([string]$Path, [string]$Target)
  $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
  if ($item) {
    if (-not $item.LinkType) { throw "$Path exists and is not a symlink; move it away first" }
    Remove-Item -LiteralPath $Path -Force
  }
  $parent = Split-Path -Parent $Path
  if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent | Out-Null }
  New-Item -ItemType SymbolicLink -Path $Path -Target $Target | Out-Null
}

Set-Location (Invoke-Git rev-parse --show-toplevel)

# .specify, specs and .claude\skills must be real symlinks. Probe inside the git dir first and stop
# before changing anything if this session is not allowed to create them.
$gitDir = (Invoke-Git rev-parse --absolute-git-dir)
$probe = Join-Path $gitDir 'symlink-probe'
$probeTarget = Join-Path $gitDir 'symlink-probe-target'
Remove-Item -LiteralPath $probe, $probeTarget -Force -ErrorAction SilentlyContinue
New-Item -ItemType File -Path $probeTarget | Out-Null
$linked = $false
try { New-Item -ItemType SymbolicLink -Path $probe -Target $probeTarget -ErrorAction Stop | Out-Null; $linked = $true } catch { }
Remove-Item -LiteralPath $probe, $probeTarget -Force -ErrorAction SilentlyContinue
if (-not $linked) {
  [Console]::Error.WriteLine('ERROR: PowerShell cannot create real symlinks here, so Spec Kit cannot be linked.')
  [Console]::Error.WriteLine('Turn on Developer Mode (Settings > System > For developers) or run PowerShell as administrator, then re-run.')
  exit 1
}

$choiceFile = Join-Path (Invoke-Git rev-parse --git-common-dir) 'speckit-harness'
$valid = 'claude-code', 'kirocrew', 'kiro-cli'
$requested = @($Harness | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
foreach ($h in $requested) {
  if ($valid -notcontains $h) { throw "unknown harness: $h" }
}
$saved = @()
if (Test-Path -LiteralPath $choiceFile) { $saved = @(Get-Content -LiteralPath $choiceFile | Where-Object { $_ }) }
$harnesses = @($requested + $saved | Sort-Object -Unique)
if ($harnesses.Count -eq 0) {
  throw 'no harness chosen; run: scripts\setup-speckit.ps1 -Harness claude-code,kirocrew,kiro-cli (any subset)'
}
Set-Content -LiteralPath $choiceFile -Value $harnesses -Encoding ascii

if (-not (Test-Path -LiteralPath '.speckit')) {
  & git show-ref --verify --quiet "refs/heads/$Branch"
  if ($LASTEXITCODE -eq 0) {
    Invoke-Git worktree add .speckit $Branch | Out-Null
  } else {
    & git fetch origin $Branch
    if ($LASTEXITCODE -ne 0) { throw "branch $Branch not found locally or on origin" }
    Invoke-Git worktree add --track -b $Branch .speckit "origin/$Branch" | Out-Null
  }
}

$root = (Get-Location).Path
New-Item -ItemType Directory -Force -Path '.speckit\specs' | Out-Null   # feature specs are written to <root>\specs; keep them on the speckit branch
New-Link (Join-Path $root '.specify') (Join-Path $root '.speckit\.specify')
New-Link (Join-Path $root 'specs') (Join-Path $root '.speckit\specs')

foreach ($h in $harnesses) {
  switch ($h) {
    'claude-code' {
      New-Link (Join-Path $root '.claude\skills') (Join-Path $root '.speckit\.claude\skills')
    }
    'kirocrew' {
      $src = Join-Path $root '.speckit\.kiro\skills'
      if (-not (Test-Path -LiteralPath $src)) { throw "missing $src" }
      New-Item -ItemType Directory -Force -Path '.kiro' | Out-Null
      Remove-Item -LiteralPath '.kiro\skills' -Recurse -Force -ErrorAction SilentlyContinue
      Copy-Item -LiteralPath $src -Destination '.kiro\skills' -Recurse
      Write-Host "synced $((Get-ChildItem '.kiro\skills').Count) skills -> .kiro\skills"
    }
    'kiro-cli' {
      $src = Join-Path $root '.speckit\.kiro\prompts'
      if (-not (Test-Path -LiteralPath $src)) {
        throw "branch $Branch has no .kiro\prompts; run 'specify integration install kiro-cli' there first"
      }
      New-Item -ItemType Directory -Force -Path '.kiro' | Out-Null
      Remove-Item -LiteralPath '.kiro\prompts' -Recurse -Force -ErrorAction SilentlyContinue
      Copy-Item -LiteralPath $src -Destination '.kiro\prompts' -Recurse
    }
  }
}
Write-Host "Spec Kit ready: .speckit (branch $Branch), .specify, specs, harnesses: $($harnesses -join ' ')"
