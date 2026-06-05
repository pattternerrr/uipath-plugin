# after-file-edit.ps1 — Cursor afterFileEdit hook.
# Cursor'da editor ile .xaml duzenlemesi POST-HOC yakalanir (Cursor'da beforeFileEdit YOK,
# yani onceden bloklanamaz — yapisal sinir). Burada: .xaml editor-edit olduysa
#   1) sert uyari (agent_message) — "geri al + edit_workflow kullan"
#   2) proje .cursor\.xaml-violation flag'i birak (Cursor stop-gate / done-gate okur)
# Kontrat: afterFileEdit bloklayamaz; sadece bilgilendirir. stdin: { file_path, edits:[...] }

$ErrorActionPreference = "SilentlyContinue"
$raw = @($input) -join "`n"
if (-not $raw) { $raw = [Console]::In.ReadToEnd() }
try { $in = $raw | ConvertFrom-Json } catch { exit 0 }

$fp = [string]$in.file_path
if ($fp -notmatch '\.xaml$') { exit 0 }   # .xaml degilse karisma

# violation flag (proje kokune yakin: dosyanin .cursor'unu bul, yoksa cwd)
$dir = Split-Path $fp -Parent
$root = $dir
while ($root -and -not (Test-Path (Join-Path $root "project.json")) -and (Split-Path $root -Parent)) {
    $parent = Split-Path $root -Parent
    if ($parent -eq $root) { break }
    $root = $parent
}
$cursorDir = Join-Path $root ".cursor"
if (Test-Path $root) {
    if (-not (Test-Path $cursorDir)) { New-Item -ItemType Directory -Path $cursorDir -Force | Out-Null }
    Set-Content -Path (Join-Path $cursorDir ".xaml-violation") -Value $fp -Encoding UTF8
}

$msg = "UYARI (Kural #3 ihlali): '$fp' editor ile elle duzenlendi. .xaml'a elle yazma YASAK. " +
       "Bu degisikligi GERI AL ve edit_workflow MCP tool'u ile yap (xmlns auto-inject + .bak). " +
       "Cursor editor-yazmayi onceden bloklayamaz; bu yuzden disiplin sart. Violation flag birakildi."
@{ permission = "allow"; agent_message = $msg; user_message = "uipath: .xaml elle duzenlendi -> edit_workflow kullan" } | ConvertTo-Json -Compress
exit 0
