# done-gate.ps1 — Claude Code Stop hook: "bitti" demeden once mekanik dogrulama.
# Kural #4 / ADR-0007: analyze 0 HATA degilse is bitmemistir.
#
# TASARIM — FAIL-OPEN (kullaniciyi ASLA tuzaga dusurme):
#   - Sadece bu session'da bir .xaml edit_workflow ile dokunulduysa calisir (flag).
#     UiPath isi yapilmadiysa / sohbetse -> hic calismaz.
#   - analyze CALISTIRILAMAZSA (CLI hata, timeout, Studio cakismasi, JSON parse fail)
#     -> BLOKLAMAZ, gecer. "cli tarafinda is varsa sorun cikmasin" -> infra belirsizse izin.
#   - SADECE analyze POZITIF olarak Data.Success=false (gercek HATA) dondurdugunde bloklar.
#   - stop_hook_active=true ise tekrar bloklamaz (sonsuz dongu korumasi).
#   - Timeout (default 90s) -> gecer.
#
# Kontrat: blokla -> stderr {"decision":"block","reason":...} + exit 2 ; izin -> exit 0.

$ErrorActionPreference = "SilentlyContinue"
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $in = $raw | ConvertFrom-Json } catch { exit 0 }

# 1) Sonsuz dongu korumasi: zaten bir stop-hook devamindaysak tekrar bloklama.
if ($in.stop_hook_active -eq $true) { exit 0 }

# 2) Proje kokunu bul (env -> stdin.cwd). Yoksa karisma.
$projDir = $env:CLAUDE_PROJECT_DIR
if (-not $projDir) { $projDir = [string]$in.cwd }
if (-not $projDir -or -not (Test-Path $projDir)) { exit 0 }
if (-not (Test-Path (Join-Path $projDir "project.json"))) { exit 0 }  # UiPath projesi degil

# 3) Bu session'da xaml dokunuldu mu? (flag yoksa is iddiasi yok -> gecer)
$flag = Join-Path $projDir ".claude\.uipath-xaml-touched"
if (-not (Test-Path $flag)) { exit 0 }

# 4) uip yoksa dogrulayamayiz -> FAIL-OPEN (gec).
if (-not (Get-Command uip -ErrorAction SilentlyContinue)) { exit 0 }

# 5) analyze'i timeout'lu calistir. uip = npm .ps1 shim -> pwsh -Command "& uip ..." ile
#    KOMUT olarak cozup calistir (kanitlanmis tek calisan yol; `pwsh -File uip.ps1` stdout basmiyor).
#    SADECE stdout JSON yakala. Hata/timeout/parse-fail -> FAIL-OPEN.
$clean = $false
$blocked = $false
try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "pwsh"
    $cmd = "& uip rpa analyze '$projDir' --output json"
    $psi.Arguments = "-NoProfile -Command `"$cmd`""
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    # KRITIK: hem stdout HEM stderr async drain edilmeli. analyze stderr'e yuzlerce [WARN]
    # yazar; stderr bosaltilmazsa buffer dolar -> process bloke -> 90sn timeout (eski bug).
    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderrTask = $proc.StandardError.ReadToEndAsync()
    if (-not $proc.WaitForExit(90000)) {
        try { $proc.Kill() } catch {}
        exit 0   # timeout -> FAIL-OPEN (uzun CLI isi olabilir, engelleme)
    }
    $stdout = $stdoutTask.Result
    $null = $stderrTask.Result   # drain (icerik onemsiz, buffer'i bosaltmak icin oku)
    # SAVUNMACI: stdout'ta JSON onunde/arkasinda log/uyari olabilir -> ilk { ... son } ayikla.
    $s = $stdout.IndexOf('{'); $e = $stdout.LastIndexOf('}')
    if ($s -ge 0 -and $e -gt $s) { $stdout = $stdout.Substring($s, $e - $s + 1) }
    $json = $stdout | ConvertFrom-Json
    # Pozitif temiz: Result=Success ve Data.Success=true. Pozitif hata: Data.Success=false.
    if ($json.Result -eq "Success" -and $json.Data.Success -eq $true) { $clean = $true }
    elseif ($json.Data.Success -eq $false) { $blocked = $true }
    # Belirsiz (parse var ama beklenmeyen sema) -> ne clean ne blocked -> FAIL-OPEN.
} catch {
    exit 0   # CLI/parse hatasi -> FAIL-OPEN
}

if ($blocked) {
    $reason = "DONE-gate: 'uip rpa analyze' HATA bildirdi (Data.Success=false). Is BITMEDI. " +
              "Hatalari 'uip rpa analyze " + $projDir + " --output json' ile gor, duzelt, sonra bitir. " +
              "Duzeltemiyorsan kullaniciya soyle (Kural #5) — 'bitti' deme."
    [Console]::Error.WriteLine((@{ decision = "block"; reason = $reason } | ConvertTo-Json -Compress))
    exit 2
}

# Temiz (veya belirsiz->fail-open): is dogrulandi, flag'i temizle, gec.
if ($clean) { Remove-Item $flag -Force -ErrorAction SilentlyContinue }
exit 0
