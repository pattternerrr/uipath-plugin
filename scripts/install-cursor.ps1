# install-cursor.ps1 — Cursor icin UiPath MCP server kaydi
#
# NEDEN bu script var: Cursor plugin sistemi su an plugin-local binary'lere isaret
# edebilecek bir ${CURSOR_PLUGIN_ROOT} degiskeni SAGLAMIYOR (Claude Code'daki
# ${CLAUDE_PLUGIN_ROOT} karsiligi yok). Public marketplace mutlak/relative path'i de
# yasakliyor. Bu yuzden MCP server'i Cursor'a kaydetmenin guvenilir yolu: bundled
# exe'nin MUTLAK yolunu cozup kullanicinin ~/.cursor/mcp.json'ina yazmak.
#
# Skills + rules zaten plugin olarak (Cursor marketplace) gelir; bu script SADECE
# MCP server'i baglar. Cursor ileride plugin-root degiskeni eklerse mcp.json plugin'e tasinabilir.
#
# Kullanim:
#   pwsh -File scripts\install-cursor.ps1            # global  (~/.cursor/mcp.json) - tum projeler
#   pwsh -File scripts\install-cursor.ps1 -Project   # proje   (.\.cursor\mcp.json) - sadece bu klasor

param(
    [switch]$Project
)

$ErrorActionPreference = "Stop"

# 1. bundled exe'nin mutlak yolu
$binExe = Join-Path (Split-Path $PSScriptRoot -Parent) "bin\UiPathMCP.exe"
if (-not (Test-Path $binExe)) {
    Write-Error "bin\UiPathMCP.exe bulunamadi ($binExe). Once: scripts\publish-bins.ps1"
    exit 1
}
$binExe = (Resolve-Path $binExe).Path

# 2. hedef mcp.json
if ($Project) {
    $cfgDir = Join-Path (Get-Location) ".cursor"
} else {
    $cfgDir = Join-Path $env:USERPROFILE ".cursor"
}
if (-not (Test-Path $cfgDir)) { New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null }
$cfgPath = Join-Path $cfgDir "mcp.json"

# 3. mevcut config'i koru, server'i ekle/guncelle
if (Test-Path $cfgPath) {
    $json = Get-Content $cfgPath -Raw | ConvertFrom-Json
} else {
    $json = [PSCustomObject]@{}
}
if (-not ($json.PSObject.Properties.Name -contains "mcpServers")) {
    $json | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue ([PSCustomObject]@{})
}

$server = [PSCustomObject]@{
    command = $binExe
    args    = @()
    env     = [PSCustomObject]@{ MCP_LEAN = "true" }
}

if ($json.mcpServers.PSObject.Properties.Name -contains "uipath-mcp-csharp") {
    $json.mcpServers."uipath-mcp-csharp" = $server
} else {
    $json.mcpServers | Add-Member -NotePropertyName "uipath-mcp-csharp" -NotePropertyValue $server
}

# 4. yaz
$json | ConvertTo-Json -Depth 10 | Set-Content -Path $cfgPath -Encoding UTF8

Write-Output "OK -> $cfgPath"
Write-Output "   server : uipath-mcp-csharp"
Write-Output "   command: $binExe"
Write-Output "   env    : MCP_LEAN=true"
Write-Output ""
Write-Output "Cursor'i yeniden baslat. Settings > MCP'de 'uipath-mcp-csharp' (7 tool) gorunmeli."
