# mark-xaml-touched.ps1 — Claude Code PostToolUse (matcher: edit_workflow MCP tool)
# edit_workflow ile bir .xaml degistiyse, done-gate'in Stop'ta dogrulama yapmasi icin
# proje koklerine .claude\.uipath-xaml-touched flag'i birakir. Sadece flag yazar; izin verir.

$ErrorActionPreference = "SilentlyContinue"
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $in = $raw | ConvertFrom-Json } catch { exit 0 }

$projDir = $env:CLAUDE_PROJECT_DIR
if (-not $projDir) { $projDir = [string]$in.cwd }
if (-not $projDir -or -not (Test-Path $projDir)) { exit 0 }

$dir = Join-Path $projDir ".claude"
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
Set-Content -Path (Join-Path $dir ".uipath-xaml-touched") -Value (Get-Date -Format o) -Encoding UTF8
exit 0
