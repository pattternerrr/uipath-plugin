# session-start.ps1 — SessionStart hook
# Ortam sağlığını + bağımlılıkları kontrol eder. stdout ajan context'ine düşer.
# Claude Code plugin spec'i auto-install desteklemediği için: eksikleri TESPİT EDİP
# kullanıcıya net install komutlarını söyleriz.

$ErrorActionPreference = "SilentlyContinue"

$root = $env:CLAUDE_PLUGIN_ROOT
$lines = @()
$missing = @()

# 1. MCP exe + bridge var mı (publish-bins çalıştırılmış mı)
$mcpExe = Join-Path $root "bin\UiPathMCP.exe"
$bridge = Join-Path $root "bin\UiPathStudioBridge.dll"
if (Test-Path $mcpExe) {
    $lines += "  [OK] MCP server exe hazir"
} else {
    $lines += "  [EKSIK] bin\UiPathMCP.exe yok -> dev: scripts\publish-bins.ps1 calistir"
}
if (-not (Test-Path $bridge)) {
    $lines += "  [UYARI] bin\UiPathStudioBridge.dll yok -> Studio pipe validation devredisi"
}

# 2. Studio acik mi (named pipe)
$pipe = Get-ChildItem "\\.\pipe\" | Where-Object { $_.Name -like "UiPathStudio*" } | Select-Object -First 1
if ($pipe) {
    $lines += "  [OK] UiPath Studio acik (pipe: $($pipe.Name)) -> anlik validation aktif"
} else {
    $lines += "  [BILGI] Studio kapali -> hybrid offline mode (CLI fallback ile dogrulama)"
}

# 3. uip CLI PATH'te mi
if (Get-Command uip -ErrorAction SilentlyContinue) {
    $lines += "  [OK] uip CLI bulundu"
} else {
    $lines += "  [EKSIK] uip CLI yok"
    $missing += "UiPath CLI kur: https://docs.uipath.com/uipath-cli/standalone/latest"
}

# 4. chrome-devtools-mcp kurulu mu (CDP selector pipeline icin)
$cdp = Join-Path $env:USERPROFILE ".claude\plugins\cache\claude-plugins-official\chrome-devtools-mcp"
if (Test-Path $cdp) {
    $lines += "  [OK] chrome-devtools-mcp kurulu (selector pipeline hazir)"
} else {
    $lines += "  [EKSIK] chrome-devtools-mcp yok"
    $missing += "/plugin install chrome-devtools-mcp@claude-plugins-official"
}

# 5. UiPath resmi skill'leri kurulu mu
$rpaSkill = Join-Path $env:USERPROFILE ".claude\commands\rpa-workflow-architect.md"
$rpaSkillAlt = Join-Path $env:USERPROFILE ".claude\skills\rpa-workflow-architect"
if ((Test-Path $rpaSkill) -or (Test-Path $rpaSkillAlt)) {
    $lines += "  [OK] UiPath resmi skill'leri kurulu"
} else {
    $lines += "  [EKSIK] UiPath resmi skill'leri yok"
    $missing += "uip skills install --agent claude"
}

# Cikti
Write-Output "=== uipath-mcp-plugin AKTIF ==="
Write-Output "ZORUNLU: UiPath/.xaml/RPA isine baslamadan ONCE 'mcp_orientation' tool'unu cagir."
Write-Output "Tum kanonik kurallar + 7 tool sozlugu orada. Her BULUNAMADI'da oraya don."
Write-Output ""
Write-Output "--- ortam kontrolu ---"
$lines | ForEach-Object { Write-Output $_ }

if ($missing.Count -gt 0) {
    Write-Output ""
    Write-Output "!! EKSIK BAGIMLILIKLAR -- kullaniciya su komutlari calistirmasini soyle:"
    $missing | ForEach-Object { Write-Output "   $_" }
    Write-Output ""
    Write-Output "   VEYA hepsini tek komutta: pwsh -File `"$root\scripts\setup.ps1`" -Target claude -Yes"
}
