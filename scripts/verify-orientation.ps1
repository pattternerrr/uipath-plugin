# verify-orientation.ps1 — F1 KAPISI: bayat binary'yi imkansiz kil.
#
# bin/UiPathMCP.exe'yi baslatip JSON-RPC ile sorgular; orientation + tools/list ciktisinin
# GERCEKTEN 7-tool lean dunyayla eslestigini assert eder. Bayat (34-tool) bir exe shiplenirse
# burada FAIL verir -> commit/push oncesi yakalanir.
#
#   pwsh -File scripts\verify-orientation.ps1
#   exit 0 = temiz, exit 1 = bayat/eksik (commit etme)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
$exe = Join-Path $repoRoot "bin\UiPathMCP.exe"

if (-not (Test-Path $exe)) { Write-Host "[FAIL] bin\UiPathMCP.exe yok ($exe)"; exit 1 }

$expected = @("mcp_orientation","set_project_root","get_activity_metadata",
              "get_workflow_outline","read_workflow","edit_workflow","fill_activity")
# Bayat (silinmis) tool/ifade isimleri — orientation metninde GORUNMEMELI.
$staleTokens = @("list_variables","add_variable","project_info","run_uipath_analyze",
                 "install_package","edit_workflow_via_studio","find_activity_by_intent",
                 "5 gaps","5 gap","list_activities","activity_recipe","get_enum_members")

$env:MCP_LEAN = "true"
$reqs = @(
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
  '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"mcp_orientation","arguments":{}}}'
) -join "`n"

$out = $reqs | & $exe 2>$null
$resp = ($out -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { try { $_ | ConvertFrom-Json } catch {} })

$fail = 0
function Bad($m) { Write-Host "  [FAIL] $m"; $script:fail++ }
function Good($m) { Write-Host "  [OK]   $m" }

Write-Host "== tools/list =="
$list = $resp | Where-Object { $_.id -eq 2 }
$names = @($list.result.tools.name)
if ($names.Count -eq 7) { Good "tam 7 tool" } else { Bad "tool sayisi $($names.Count) (beklenen 7): $($names -join ', ')" }
foreach ($e in $expected) {
    if ($names -contains $e) { Good "tool var: $e" } else { Bad "tool EKSIK: $e" }
}
$extra = @($names | Where-Object { $expected -notcontains $_ })
if ($extra.Count -gt 0) { Bad "fazladan tool: $($extra -join ', ')" }

Write-Host "== mcp_orientation metni =="
$orient = $resp | Where-Object { $_.id -eq 3 }
$text = [string]$orient.result.content[0].text
if ([string]::IsNullOrWhiteSpace($text)) { Bad "orientation metni bos" }
else {
    $hit = @($staleTokens | Where-Object { $text -match [regex]::Escape($_) })
    if ($hit.Count -eq 0) { Good "bayat token YOK" } else { Bad "BAYAT token bulundu: $($hit -join ', ')" }
    if ($text -match "fill_activity") { Good "metinde fill_activity geciyor" } else { Bad "metinde fill_activity yok" }
}

Write-Host ""
if ($fail -eq 0) { Write-Host "== SONUC: TEMIZ (7-tool lean, bayat yok) =="; exit 0 }
else { Write-Host "== SONUC: $fail FAIL -> bu exe BAYAT/EKSIK, commit etme =="; exit 1 }
