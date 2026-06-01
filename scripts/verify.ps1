# verify.ps1 — UiPath plugin kurulum DOKTORU (Cursor)
#
# "Kurulum dogru mu?" diye kontrol eder, rapor basar. -Fix verilirse eksikleri tamamlar.
#
#   pwsh -File scripts\verify.ps1                       # sadece RAPOR (mevcut klasoru proje sayar)
#   pwsh -File scripts\verify.ps1 -Project C:\...\proje # belirli projeyi kontrol et
#   pwsh -File scripts\verify.ps1 -Fix                  # eksikleri otomatik tamamla
#
# Tum kontroller idempotent; -Fix yalnizca EKSIK/YANLIS olani onarir (saglamlari atlar).

param(
    [string]$Project,
    [switch]$Fix
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
$binExe   = Join-Path $repoRoot "bin\UiPathMCP.exe"
$cursorHome = Join-Path $env:USERPROFILE ".cursor"
$mcpCfg   = Join-Path $cursorHome "mcp.json"
if (-not $Project) { $Project = (Get-Location).Path }
$projCursor = Join-Path $Project ".cursor"

$pass = 0; $fail = 0; $fixed = 0
function Pass($m) { Write-Output "  [OK]   $m"; $script:pass++ }
function Fail($m) { Write-Output "  [FAIL] $m"; $script:fail++ }
function Did($m)  { Write-Output "  [FIX]  $m";  $script:fixed++ }

Write-Output ""
Write-Output "============================================================"
Write-Output "  UiPath plugin verify  (proje: $Project)"
Write-Output "  Mod: $(if ($Fix) { 'CHECK + FIX' } else { 'sadece CHECK' })"
Write-Output "============================================================"

# --- 0. repo bütünlüğü ---
Write-Output ""
Write-Output "-- repo / binary --"
if (Test-Path $binExe) { Pass "bin\UiPathMCP.exe mevcut" }
else { Fail "bin\UiPathMCP.exe YOK ($binExe) — clone eksik/AV karantina?" }

# --- 1. önkoşullar ---
Write-Output ""
Write-Output "-- onkosullar --"
if (Get-Command uip -ErrorAction SilentlyContinue) { Pass "uip CLI bulundu" }
else { Fail "uip CLI yok — https://docs.uipath.com/uipath-cli/standalone/latest" }
if (Get-Command npx -ErrorAction SilentlyContinue) { Pass "npx (Node) bulundu — chrome-devtools-mcp icin" }
else { Fail "npx yok — chrome-devtools-mcp calismaz (Node.js kur)" }

# --- 2. MCP kaydi (global ~/.cursor/mcp.json) ---
Write-Output ""
Write-Output "-- MCP kaydi (~/.cursor/mcp.json) --"
$mcpOk = $false
if (Test-Path $mcpCfg) {
    $j = Get-Content $mcpCfg -Raw | ConvertFrom-Json
    $srv = if ($j.PSObject.Properties.Name -contains "mcpServers" -and
               $j.mcpServers.PSObject.Properties.Name -contains "uipath-mcp-csharp") { $j.mcpServers.'uipath-mcp-csharp' } else { $null }
    if ($srv -and $srv.command -eq $binExe -and $srv.env.MCP_LEAN -eq "true") {
        Pass "uipath-mcp-csharp -> plugin bin + MCP_LEAN=true"
        $mcpOk = $true
    } elseif ($srv) {
        Fail "uipath-mcp-csharp var ama yanlis: command='$($srv.command)' (beklenen: $binExe)"
    } else {
        Fail "uipath-mcp-csharp kaydi YOK"
    }
} else { Fail "mcp.json yok ($mcpCfg)" }
if (-not $mcpOk -and $Fix -and (Test-Path $binExe)) {
    if (-not (Test-Path $cursorHome)) { New-Item -ItemType Directory -Path $cursorHome -Force | Out-Null }
    if (Test-Path $mcpCfg) { Copy-Item $mcpCfg "$mcpCfg.bak" -Force; $j = Get-Content $mcpCfg -Raw | ConvertFrom-Json }
    else { $j = [PSCustomObject]@{} }
    if (-not ($j.PSObject.Properties.Name -contains "mcpServers")) { $j | Add-Member mcpServers ([PSCustomObject]@{}) }
    $newSrv = [PSCustomObject]@{ type="stdio"; command=$binExe; args=@(); env=[PSCustomObject]@{ MCP_LEAN="true" } }
    if ($j.mcpServers.PSObject.Properties.Name -contains "uipath-mcp-csharp") { $j.mcpServers.'uipath-mcp-csharp' = $newSrv }
    else { $j.mcpServers | Add-Member "uipath-mcp-csharp" $newSrv }
    $j | ConvertTo-Json -Depth 10 | Set-Content $mcpCfg -Encoding UTF8
    Did "uipath-mcp-csharp -> plugin bin yazildi"
}

# --- 3. bayat global rule ---
Write-Output ""
Write-Output "-- bayat artifact --"
$stale = Join-Path $cursorHome "rules\uipath-mcp-only.mdc"
if (Test-Path $stale) {
    Fail "bayat global rule aktif: uipath-mcp-only.mdc (silinmis tool'lara isaret eder)"
    if ($Fix) { Move-Item $stale "$stale.bak" -Force; Did "uipath-mcp-only.mdc -> .bak" }
} else { Pass "bayat global rule yok/devre disi" }

# --- 4. proje-scope rules + skills + AGENTS ---
Write-Output ""
Write-Output "-- proje: $projCursor --"
if (-not (Test-Path (Join-Path $Project "project.json"))) {
    Write-Output "  [..]   Uyari: bu klasor UiPath projesi degil (project.json yok). -Project ile dogru klasoru ver."
}
# rules
$ruleNames = @("uipath-orientation.mdc", "uipath-xaml.mdc")
$missingRules = @($ruleNames | Where-Object { -not (Test-Path (Join-Path $projCursor "rules\$_")) })
if ($missingRules.Count -eq 0) { Pass "rules: $($ruleNames -join ', ')" }
else {
    Fail "eksik rules: $($missingRules -join ', ')"
    if ($Fix) {
        New-Item -ItemType Directory -Force -Path (Join-Path $projCursor "rules") | Out-Null
        Copy-Item (Join-Path $repoRoot "rules\*") (Join-Path $projCursor "rules") -Recurse -Force
        Did "rules kopyalandi"
    }
}
# skills
$skillNames = @("ui-activity", "cdp-selector-pipeline", "issue-tracker", "triage-labels", "domain")
$missingSkills = @($skillNames | Where-Object { -not (Test-Path (Join-Path $projCursor "skills\$_")) })
if ($missingSkills.Count -eq 0) { Pass "skills: 5/5" }
else {
    Fail "eksik skills: $($missingSkills -join ', ')"
    if ($Fix) {
        New-Item -ItemType Directory -Force -Path (Join-Path $projCursor "skills") | Out-Null
        Copy-Item (Join-Path $repoRoot "skills\*") (Join-Path $projCursor "skills") -Recurse -Force
        Did "skills kopyalandi"
    }
}
# AGENTS.md
$agents = Join-Path $Project "AGENTS.md"
if (Test-Path $agents) { Pass "AGENTS.md mevcut" }
else {
    Fail "AGENTS.md yok"
    if ($Fix) { Copy-Item (Join-Path $repoRoot "AGENTS.md") $agents; Did "AGENTS.md kopyalandi" }
}

# --- ozet ---
Write-Output ""
Write-Output "============================================================"
Write-Output "  Sonuc: $pass OK, $fail FAIL$(if ($Fix) { ", $fixed FIX" })"
if ($fail -gt 0 -and -not $Fix) {
    Write-Output "  -> Duzeltmek icin: pwsh -File scripts\verify.ps1 -Project `"$Project`" -Fix"
}
if ($fixed -gt 0 -or ($Fix -and $fail -gt 0)) {
    Write-Output "  -> Cursor'i yeniden baslat (MCP/rules degisti)."
}
Write-Output "============================================================"
# CI/script kullanimi icin: hata varsa non-zero (fix sonrasi kalan fail)
if ($fail -gt 0 -and -not $Fix) { exit 1 } else { exit 0 }
