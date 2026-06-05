# test-transport.ps1 — F2 KAPISI: MCP stdio transport oturum-ortasi disconnect'e dayanikli mi?
#
# Yeni binary'yi, F2'ye yol acan girdi sinifiyla dover:
#   - JSON-RPC notification (notifications/initialized, notifications/cancelled) -> YANIT VERMEMELI
#   - bozuk/garbage satir -> atlanmali, loop OLMEMELI
#   - en son disconnect'te olen get_workflow_outline cagrisi -> normal sonuc donmeli
#   - 50x hammer -> hepsi yanitlanmali, process EOF'a kadar ayakta
#
#   pwsh -File scripts\test-transport.ps1   (exit 0 = saglam, exit 1 = disconnect/eksik yanit)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
$exe = Join-Path $repoRoot "bin\UiPathMCP.exe"
if (-not (Test-Path $exe)) { Write-Host "[FAIL] bin\UiPathMCP.exe yok"; exit 1 }

$proj = "C:\Users\mustafa.basar\Documents\UiPath\eticaretkopya"
$wf   = Join-Path $proj "Workflows\SearchTrendyol.xaml"
$env:MCP_LEAN = "true"

# NOT: parametre adi $a — $args PowerShell'in otomatik degiskeni, cakisir (arguments'i bozar).
function Req($id, $name, $a)      { @{ jsonrpc="2.0"; id=$id; method="tools/call"; params=@{ name=$name; arguments=$a } } | ConvertTo-Json -Compress -Depth 8 }
function Note($method, $p)        { @{ jsonrpc="2.0"; method=$method; params=$p } | ConvertTo-Json -Compress -Depth 6 }

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add((@{ jsonrpc="2.0"; id=1; method="initialize"; params=@{} } | ConvertTo-Json -Compress))
$lines.Add((Note "notifications/initialized" @{}))                 # bildirim — yanit YOK
$lines.Add((Req 2 "mcp_orientation" @{}))
$lines.Add((Req 3 "set_project_root" @{ projectRoot=$proj }))
$lines.Add((Note "notifications/cancelled" @{ requestId=2 }))      # supheli katil — yanit YOK
$lines.Add('{ bu gecerli json DEGIL >>> kirik satir')             # garbage — atlanmali
$lines.Add((Req 4 "get_workflow_outline" @{ workflowFilePath=$wf }))  # son kez burada oldu
100..149 | ForEach-Object { $lines.Add((Req $_ "mcp_orientation" @{})) }  # 50x hammer

$expectedIds = @(1,2,3,4) + (100..149)   # 54 istek; 2 bildirim + 1 garbage = 0 yanit
$payload = ($lines -join "`n")

$errFile = Join-Path $env:TEMP "uipath_mcp_transport_stderr.txt"
$out = $payload | & $exe 2>$errFile
$resp = $out -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { try { $_ | ConvertFrom-Json } catch {} }

$fail = 0
function Bad($m) { Write-Host "  [FAIL] $m"; $script:fail++ }
function Good($m){ Write-Host "  [OK]   $m" }

$ids = @($resp | ForEach-Object { $_.id })
Write-Host "== yanit sayisi: $($ids.Count) (beklenen $($expectedIds.Count)) =="
if ($ids.Count -eq $expectedIds.Count) { Good "tam $($expectedIds.Count) yanit" }
else { Bad "yanit sayisi $($ids.Count) != $($expectedIds.Count) (kayip yanit = disconnect/olu loop)" }

$missing = @($expectedIds | Where-Object { $ids -notcontains $_ })
if ($missing.Count -eq 0) { Good "tum istek id'leri yanitlandi" } else { Bad "yanitsiz id'ler: $($missing -join ', ')" }

$nullId = @($resp | Where-Object { $null -eq $_.id })
if ($nullId.Count -eq 0) { Good "bildirimlere yanit YOK (protokol dogru)" }
else { Bad "$($nullId.Count) bildirime yanit donmus (JSON-RPC ihlali — disconnect riski)" }

$outline = $resp | Where-Object { $_.id -eq 4 } | Select-Object -First 1
if ($outline.result -and -not $outline.error) { Good "get_workflow_outline (son kez olen cagri) saglam sonuc dondu" }
elseif ($outline.error) { Bad "get_workflow_outline error: $($outline.error.message)" }
else { Bad "get_workflow_outline yaniti yok" }

$stderr = if (Test-Path $errFile) { Get-Content $errFile -Raw } else { "" }
if ($stderr -match "\[mcp\]") { Write-Host "  [bilgi] stderr recovery logu (loop hayatta kaldi): $($stderr.Trim())" }

Write-Host ""
if ($fail -eq 0) { Write-Host "== SONUC: TRANSPORT SAGLAM — 54 cagri, disconnect yok, bildirimler temiz =="; exit 0 }
else { Write-Host "== SONUC: $fail FAIL — transport hala kirik =="; exit 1 }
