# update.ps1 — ARKADAS TEK-KOMUT GUNCELLEME + TEMIZLIK
#
# Repo'daki son duzeltmeleri ceker, binary'nin DOGRU oldugunu dogrular, kurulumu
# tamamlar/onarir. Bayat binary (F1), disconnect (F2), taze-proje metadata (F3)
# duzeltmeleri bu komutla arkadasa gecer.
#
# KULLANIM: UiPath PROJE klasorunde calistir (rules/skills oraya kopyalanir):
#   pwsh -File <plugin>\scripts\update.ps1                 # Cursor (varsayilan)
#   pwsh -File <plugin>\scripts\update.ps1 -Target both    # Cursor + Claude
#   pwsh -File <plugin>\scripts\update.ps1 -Project C:\...\proje   # baska proje

param(
    [ValidateSet("cursor","claude","both")] [string]$Target = "cursor",
    [string]$Project,
    [switch]$SkipPull
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
if (-not $Project) { $Project = (Get-Location).Path }

function Head($m) { Write-Output ""; Write-Output "=== $m ===" }
function Ok($m)   { Write-Output "  [OK]  $m" }
function Warn($m) { Write-Output "  [!!]  $m" }
function Info($m) { Write-Output "  [..]  $m" }

Write-Output "############################################################"
Write-Output "#  UiPath plugin — guncelleme + temizlik (tek komut)"
Write-Output "#  plugin : $repoRoot"
Write-Output "#  proje  : $Project"
Write-Output "############################################################"

# --- 1. git pull (duzeltmeleri cek) ---
Head "1/5  git pull — son duzeltmeler (F1/F2/F3)"
if ($SkipPull) { Info "atlandi (-SkipPull)" }
elseif (Test-Path (Join-Path $repoRoot ".git")) {
    try {
        $before = (& git -C $repoRoot rev-parse --short HEAD 2>$null)
        & git -C $repoRoot pull --ff-only 2>&1 | ForEach-Object { Write-Output "      $_" }
        $after = (& git -C $repoRoot rev-parse --short HEAD 2>$null)
        if ($before -eq $after) { Ok "zaten guncel ($after)" } else { Ok "guncellendi: $before -> $after" }
    } catch {
        Warn "git pull basarisiz: $($_.Exception.Message)"
        Warn "  -> Elle: git -C `"$repoRoot`" pull   (yerel degisiklik varsa once stash)"
    }
} else { Warn "$repoRoot bir git deposu degil — pull atlandi (zip ile mi kuruldu?)" }

# --- 2. binary DOGRU mu? (verify-orientation kapisi) ---
Head "2/5  binary dogrulama (7-tool, bayat yok)"
$vok = $true
try {
    & "$PSScriptRoot\verify-orientation.ps1" | Out-Null
    if ($LASTEXITCODE -eq 0) { Ok "orientation TEMIZ — 7 tool, bayat token yok" }
    else { $vok = $false }
} catch { $vok = $false }
if (-not $vok) {
    Warn "binary dogrulanamadi. Olasi: AV exe'yi karantinaya aldi, ya da pull eksik."
    Warn "  -> bin\UiPathMCP.exe var mi kontrol et; AV karantinasindan geri yukle;"
    Warn "     klasoru AV haric-tut listesine ekle. (Detay: README antivirus notu.)"
}

# --- 3. onkosullar (NET GEREKMEZ, Node opsiyonel) ---
Head "3/5  onkosullar"
$bin = Join-Path $repoRoot "bin\UiPathMCP.exe"
if (Test-Path $bin) { Ok "MCP self-contained ($([math]::Round((Get-Item $bin).Length/1KB))KB launcher) — .NET KURULUMU GEREKMEZ" }
else { Warn "bin\UiPathMCP.exe YOK — clone/AV problemi" }
if (Get-Command uip -ErrorAction SilentlyContinue) { Ok "uip CLI var (validate/build/run/restore/activities/packages)" }
else { Warn "uip CLI YOK — analyze/restore/paket kesfi calismaz. https://docs.uipath.com/uipath-cli/standalone/latest" }
if (Get-Command npx -ErrorAction SilentlyContinue) { Ok "npx (Node) var — chrome-devtools-mcp (web selector) icin" }
else { Info "npx YOK — Node yalnizca WEB otomasyonu (chrome-devtools) icin gerekir. XAML isi Node'suz calisir." }

# --- 4. kurulum (MCP kaydi + rules/skills + bayat artifact temizligi) ---
Head "4/5  setup — MCP kaydi + rules/skills + bayat temizlik"
Push-Location $Project
try { & "$PSScriptRoot\setup.ps1" -Target $Target -Yes | ForEach-Object { Write-Output "      $_" } }
catch { Warn "setup hata: $($_.Exception.Message)" }
finally { Pop-Location }

# --- 5. dogrulama + eksik onar ---
Head "5/5  verify -Fix — eksik/yanlis ne varsa onar"
try { & "$PSScriptRoot\verify.ps1" -Project $Project -Fix | ForEach-Object { Write-Output "      $_" } }
catch { Warn "verify hata: $($_.Exception.Message)" }

Write-Output ""
Write-Output "############################################################"
Write-Output "#  BITTI. Son adim: $(if ($Target -eq 'claude') { 'Claude Code' } else { 'Cursor' })'i YENIDEN BASLAT"
Write-Output "#  (MCP/rules degisti — restart olmadan eski hali kullanir)."
Write-Output "############################################################"
