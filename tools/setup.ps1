# One-command setup for Windows (also works in PowerShell 7 on Linux/macOS).
# Checks Node and Godot, then installs npm dependencies. Run from anywhere:
#   tools\setup.cmd            (or)   powershell -ExecutionPolicy Bypass -File tools\setup.ps1
# Exit 0 = ready (warnings allowed). Exit 1 = a required tool is missing or an install failed.
# Docs: docs/tools/README.md

$WantNodeMajor = 24   # the golden hashes were recorded on Node 24.19.0 (ADR 0004)
$MinNodeMajor  = 18   # the lowest major qa/ and sim/ run on
$WantGodot     = '4.7' # ADR 0001

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..')
$script:warnings = 0
function Ok($m)   { Write-Host "ok    $m" }
function Warn($m) { Write-Host "WARN  $m"; $script:warnings++ }
function Fail($m) { Write-Host "FAIL  $m"; exit 1 }

# Node (required)
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Fail "node not found. Install Node $WantNodeMajor (https://nodejs.org) and re-run." }
$nodeV = (& node -v).Trim()
$nodeMajor = [int]($nodeV.TrimStart('v').Split('.')[0])
if ($nodeMajor -lt $MinNodeMajor) { Fail "Node $nodeV is too old (need $MinNodeMajor or newer, $WantNodeMajor recommended)." }
if ($nodeMajor -eq $WantNodeMajor) { Ok "Node $nodeV" }
else { Warn "Node ${nodeV}: Node $WantNodeMajor is the tested version. The golden-hash check is skipped on other majors, so a pass here proves less." }
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { Fail 'npm not found (it ships with Node).' }
Ok "npm $((& npm -v).Trim())"

# Godot (optional until the GDScript port lands)
$godotBin = $null
$candidates = @($env:GODOT, 'godot', 'godot4', 'Godot_v4.7.2-stable_win64_console.exe', 'Godot_v4.7.2-stable_win64.exe') | Where-Object { $_ }
foreach ($c in $candidates) {
  $cmd = Get-Command $c -ErrorAction SilentlyContinue
  if ($cmd) { $godotBin = $cmd.Source; break }
}
if (-not $godotBin) {
  Warn "Godot not found. Not needed for the JavaScript suites. For the engine port install Godot $WantGodot.x (standard build, not .NET) and put it on PATH, or set `$env:GODOT to its path."
} else {
  $godotV = ((& $godotBin --version 2>$null) | Select-Object -First 1)
  if ($godotV -like "$WantGodot.*") { Ok "Godot $godotV ($godotBin)" }
  else { Warn "Godot reports '$godotV'; the project targets $WantGodot.x (ADR 0001)." }
  if ($godotV -match 'mono|\.NET') { Warn 'This looks like the .NET build; the project uses GDScript, use the standard build.' }
}

# npm dependencies: `npm ci` in each package that has a lockfile. Today none of
# qa/, sim/ or the root declares dependencies, and prototype/'s only entry is the
# optional screenshot canvas, so this is usually a no-op.
$installed = 0
foreach ($dir in '.', 'prototype', 'sim', 'qa') {
  if (-not (Test-Path (Join-Path $dir 'package.json'))) { continue }
  if (Test-Path (Join-Path $dir 'package-lock.json')) {
    Write-Host "npm ci in $dir"
    Push-Location $dir
    & npm ci
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -ne 0) { Fail "npm ci failed in $dir" }
    $installed++
  }
}
if ($installed -eq 0) { Ok 'no lockfiles, nothing to install (the suites use Node built-ins only)' }

Write-Host ''
if ($script:warnings -eq 0) { Write-Host 'Setup complete.' } else { Write-Host "Setup complete with $($script:warnings) warning(s)." }
Write-Host 'Next: node qa/run-all.js --quick   (about 40 s)   or   npm test --prefix sim'
exit 0
