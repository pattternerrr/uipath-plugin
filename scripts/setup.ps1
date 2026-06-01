# setup.ps1 — UiPath plugin TEK KOMUT kurulum sihirbazi (Claude Code + Cursor)
#
# Arkadas modu: dizini OTOMATIK secer, hepsini kurar:
#   - UiPath MCP server (7 tool)  -> bundled bin\UiPathMCP.exe mutlak yol
#   - chrome-devtools-mcp         -> npx chrome-devtools-mcp@latest (web selector pipeline)
#   - UiPath resmi skill'leri     -> uip skills install --agent <cursor|claude>
#
# Calistirma (repo klasorunde):
#   pwsh -File scripts\setup.ps1                 # interaktif menu
#   pwsh -File scripts\setup.ps1 -Yes            # soru sormadan: Cursor + global
#   pwsh -File scripts\setup.ps1 -Target cursor -Scope global -Yes
#   pwsh -File scripts\setup.ps1 -Target claude  -Yes
#
# NEDEN script: Cursor'da plugin-local exe'ye isaret eden ${CURSOR_PLUGIN_ROOT} yok.
# MCP server'i baglamanin guvenilir yolu mutlak yolu config'e yazmak.

param(
    [ValidateSet("cursor", "claude", "both")] [string]$Target,
    [ValidateSet("global", "local")]          [string]$Scope = "global",
    [switch]$Yes,
    [switch]$SkipChrome,
    [switch]$SkipSkills
)

$ErrorActionPreference = "Stop"
function Say($m) { Write-Output $m }
function Ok($m)  { Write-Output "  [OK]  $m" }
function Warn($m){ Write-Output "  [!!]  $m" }
function Info($m){ Write-Output "  [..]  $m" }

Say ""
Say "============================================================"
Say "   UiPath plugin kurulum sihirbazi  (Claude Code + Cursor)"
Say "============================================================"

# --- 0. bundled MCP exe mutlak yolu ---
$repoRoot = Split-Path $PSScriptRoot -Parent
$binExe = Join-Path $repoRoot "bin\UiPathMCP.exe"
if (-not (Test-Path $binExe)) {
    Warn "bin\UiPathMCP.exe yok ($binExe)"
    Warn "Repo'yu klonladin mi? Dev isen once: scripts\publish-bins.ps1"
    exit 1
}
$binExe = (Resolve-Path $binExe).Path

# --- 1. hedef ajan ---
if (-not $Target) {
    if ($Yes) {
        $Target = "cursor"
    } else {
        Say ""
        Say "Hangi ajan icin kuralim?"
        Say "  1) Cursor"
        Say "  2) Claude Code"
        Say "  3) Ikisi de"
        $sel = Read-Host "Secim [1]"
        switch ($sel) { "2" { $Target = "claude" } "3" { $Target = "both" } default { $Target = "cursor" } }
    }
}
Info "Hedef: $Target  |  Kapsam: $Scope"

# --- yardimci: bir mcp.json'a server ekle/guncelle (mevcutu ezmeden) ---
function Merge-McpServer {
    param([string]$CfgPath, [string]$Name, [object]$Server)
    $dir = Split-Path $CfgPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (Test-Path $CfgPath) { $json = Get-Content $CfgPath -Raw | ConvertFrom-Json }
    else { $json = [PSCustomObject]@{} }
    if (-not ($json.PSObject.Properties.Name -contains "mcpServers")) {
        $json | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue ([PSCustomObject]@{})
    }
    if ($json.mcpServers.PSObject.Properties.Name -contains $Name) { $json.mcpServers.$Name = $Server }
    else { $json.mcpServers | Add-Member -NotePropertyName $Name -NotePropertyValue $Server }
    $json | ConvertTo-Json -Depth 10 | Set-Content -Path $CfgPath -Encoding UTF8
}

# --- yardimci: kaynak klasoru hedefe kopyala (hedefi olusturur, icindekileri ezer) ---
function Copy-Tree {
    param([string]$Src, [string]$Dst)
    if (-not (Test-Path $Src)) { return $false }
    if (-not (Test-Path $Dst)) { New-Item -ItemType Directory -Path $Dst -Force | Out-Null }
    Copy-Item -Path (Join-Path $Src "*") -Destination $Dst -Recurse -Force
    return $true
}

# --- yardimci: bilinen bayat artifact'lari devre disi birak (eski 34-tool donemi) ---
# Arkadaslarda genelde yoktur (no-op); eski/bozuk kurulum kalmissa tek komutla temizler.
function Disable-StaleArtifacts {
    param([string]$CursorHome)
    # Bayat global rule: silinmis tool'lara (install_package/create_workflow/validate_xml) "zorunlu" diye
    # isaret edip agent'i CLI yerine olmayan MCP tool'una yonlendiriyordu. Silmiyoruz, .bak'a tasiyoruz.
    $staleRule = Join-Path $CursorHome "rules\uipath-mcp-only.mdc"
    if (Test-Path $staleRule) {
        $bak = "$staleRule.bak"
        if (Test-Path $bak) { Remove-Item $bak -Force }
        Move-Item $staleRule $bak -Force
        Warn "Bayat global rule devre disi: uipath-mcp-only.mdc -> .bak (silinmis tool'lara isaret ediyordu)"
    }
    # Eski JS MCP server kaydi (iptal edilen uipath-workflow-tools) -> sadece uyar, ezme/silme.
    $cfg = Join-Path $CursorHome "mcp.json"
    if (Test-Path $cfg) {
        $j = Get-Content $cfg -Raw | ConvertFrom-Json
        if ($j.PSObject.Properties.Name -contains "mcpServers" -and
            $j.mcpServers.PSObject.Properties.Name -contains "uipath-workflow-tools") {
            Warn "Eski 'uipath-workflow-tools' (legacy JS) mcp.json'da duruyor -> kullanmiyorsan elle sil."
        }
    }
    # Cift-kayit riski: Cursor marketplace'ten ayni plugin import edilmisse, MCP+rules cakisir.
    # Generic var/yok kontrolu (klasor yapisi tahmin edilmez): plugins\ altinda plugin adi geciyor mu.
    $pluginsDir = Join-Path $CursorHome "plugins"
    if (Test-Path $pluginsDir) {
        $hit = Get-ChildItem $pluginsDir -Recurse -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -like "*uipath-mcp-plugin*" } | Select-Object -First 1
        if ($hit) {
            Warn "Marketplace import tespit edildi: $($hit.FullName)"
            Warn "  -> CIFT KAYIT riski. Cursor: Settings/Plugins -> uipath-mcp-plugin import'u KALDIR."
            Warn "     Tek kaynak script olsun (MCP+rules+skills bu script'ten gelir)."
        }
    }
}

$uipExists = [bool](Get-Command uip -ErrorAction SilentlyContinue)
$npxExists = [bool](Get-Command npx -ErrorAction SilentlyContinue)

# ============================ CURSOR ============================
if ($Target -eq "cursor" -or $Target -eq "both") {
    Say ""
    Say "--- Cursor ---"
    # dizin OTOMATIK: global -> ~/.cursor, local -> ./.cursor
    if ($Scope -eq "local") { $cfgDir = Join-Path (Get-Location) ".cursor" }
    else                    { $cfgDir = Join-Path $env:USERPROFILE ".cursor" }
    $cfg = Join-Path $cfgDir "mcp.json"

    # 0) temizlik: bayat artifact'lar (global ~/.cursor, scope'tan bagimsiz)
    Disable-StaleArtifacts -CursorHome (Join-Path $env:USERPROFILE ".cursor")

    # 1) UiPath MCP server
    Merge-McpServer -CfgPath $cfg -Name "uipath-mcp-csharp" -Server ([PSCustomObject]@{
        command = $binExe; args = @(); env = [PSCustomObject]@{ MCP_LEAN = "true" }
    })
    Ok "UiPath MCP -> $cfg (uipath-mcp-csharp, 7 tool)"

    # 2) chrome-devtools-mcp (npx)
    if (-not $SkipChrome) {
        if ($npxExists) {
            Merge-McpServer -CfgPath $cfg -Name "chrome-devtools" -Server ([PSCustomObject]@{
                command = "npx"; args = @("chrome-devtools-mcp@latest")
            })
            Ok "chrome-devtools -> $cfg (npx chrome-devtools-mcp@latest)"
        } else {
            Warn "npx yok (Node.js kurulu degil) -> chrome-devtools atlandi. Node kurup tekrar calistir."
        }
    }

    # 3) UiPath resmi skill'leri
    if (-not $SkipSkills) {
        if ($uipExists) {
            $skArgs = @("skills", "install", "--agent", "cursor")
            if ($Scope -eq "local") { $skArgs += "--local" }
            try { & uip @skArgs | Out-Null; Ok "UiPath skill'leri -> agent cursor ($Scope)" }
            catch { Warn "uip skills install hata: $($_.Exception.Message) (uip login gerekebilir)" }
        } else { Warn "uip CLI yok -> skill kurulamadi. https://docs.uipath.com/uipath-cli/standalone/latest" }
    }

    # 4) plugin'in KENDI rules + skills'i -> PROJE .cursor/ (marketplace import gerekmesin diye)
    #    ONEMLI: Cursor rules/skills SADECE proje-scope dosya yolundan yuklenir.
    #    Global ~/.cursor/rules dokumante edilmis bir load path DEGIL (global = Settings/Rules UI).
    #    Skills: <proje>/.cursor/skills/ recursive auto-discover. Bu yuzden $Scope'tan bagimsiz,
    #    her zaman calisilan projenin .cursor'una kopyalanir. (Komutu UiPath proje klasorunde calistir.)
    $projCursor = Join-Path (Get-Location) ".cursor"
    if (Copy-Tree (Join-Path $repoRoot "rules") (Join-Path $projCursor "rules")) {
        Ok "plugin rules -> $projCursor\rules (uipath-orientation + uipath-xaml, alwaysApply)"
    } else { Warn "rules\ bulunamadi (repo eksik?)" }
    if (Copy-Tree (Join-Path $repoRoot "skills") (Join-Path $projCursor "skills")) {
        Ok "plugin skills -> $projCursor\skills (ui-activity, cdp-selector-pipeline, ...)"
    } else { Warn "skills\ bulunamadi (repo eksik?)" }

    # 5) AGENTS.md -> proje koku (Cursor CLAUDE.md okumaz, AGENTS.md okur).
    $agentsSrc = Join-Path $repoRoot "AGENTS.md"
    $agentsDst = Join-Path (Get-Location) "AGENTS.md"
    if (Test-Path $agentsSrc) {
        if (Test-Path $agentsDst) { Warn "AGENTS.md zaten var -> ezilmedi ($agentsDst)" }
        else { Copy-Item $agentsSrc $agentsDst; Ok "AGENTS.md -> $agentsDst (derin referans, Cursor okur)" }
    }

    if ($Scope -eq "global") {
        Info "Not: MCP global'e yazildi ama rules/skills proje-scope (Cursor global rules dosyadan yuklenmez)."
        Info "     Komutu UiPath proje klasorunde calistirdigindan emin ol; rules/skills oraya indi."
    }
}

# ============================ CLAUDE ============================
if ($Target -eq "claude" -or $Target -eq "both") {
    Say ""
    Say "--- Claude Code ---"
    # Claude'da MCP + bizim skills/rules/hook plugin'in KENDISIYLE gelir (marketplace).
    # Bir ps1 slash-command calistiramaz; o adimlar Claude icinde yazilir.
    if (-not $SkipSkills) {
        if ($uipExists) {
            $skArgs = @("skills", "install", "--agent", "claude")
            if ($Scope -eq "local") { $skArgs += "--local" }
            try { & uip @skArgs | Out-Null; Ok "UiPath skill'leri -> agent claude ($Scope)" }
            catch { Warn "uip skills install hata: $($_.Exception.Message) (uip login gerekebilir)" }
        } else { Warn "uip CLI yok -> skill kurulamadi." }
    }
    Say ""
    Say "  Claude Code icinde su 3 satiri yaz (ps1 slash-command calistiramaz):"
    Say "     /plugin marketplace add pattternerrr/uipath-plugin"
    Say "     /plugin install uipath-mcp-plugin@mustafa-uipath"
    Say "     /plugin install chrome-devtools-mcp@claude-plugins-official"
}

# ============================ OZET ============================
Say ""
Say "============================================================"
Say "  Kurulum bitti. Dogrulama:"
if ($Target -ne "claude") {
    Say "   Cursor  -> yeniden baslat -> Settings/MCP: uipath-mcp-csharp (7 tool) + chrome-devtools"
    Say "             Settings/Rules : uipath-orientation (Always) + uipath-xaml (Always)"
    Say "             rules + skills + AGENTS.md script tarafindan kopyalandi (marketplace import GEREKMEZ)"
}
if ($Target -ne "cursor") {
    Say "   Claude  -> /mcp: uipath-mcp-csharp (7 tool) ; /plugin: uipath-mcp-plugin enabled"
}
Say "============================================================"
