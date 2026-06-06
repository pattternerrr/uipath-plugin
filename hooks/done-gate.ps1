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

# 2b) OPT-IN: done-gate VARSAYILAN KAPALI. analyze Studio kapaliyken ~20sn surer; her
#     tamamlamada bunu odemek istemeyen kullanici default'ta hic beklemesin. Sert kapiyi
#     isteyen proje kokune .claude\uipath-done-gate.enabled dosyasi koyar.
#     (block-xaml PreToolUse zaten HEP acik — asil elle-xaml engellemesi ondan gelir.)
if (-not (Test-Path (Join-Path $projDir ".claude\uipath-done-gate.enabled"))) { exit 0 }

# 3) Bu session'da xaml dokunuldu mu? (flag yoksa is iddiasi yok -> gecer)
$flag = Join-Path $projDir ".claude\.uipath-xaml-touched"
if (-not (Test-Path $flag)) { exit 0 }

# 4) uip yoksa dogrulayamayiz -> FAIL-OPEN (gec).
if (-not (Get-Command uip -ErrorAction SilentlyContinue)) { exit 0 }

# 5) `uip rpa build` ile DERLE — analyze/validate DEGIL.
#    CANLI KANIT (HH projesi): `uip rpa validate` "No diagnostics" derken `uip rpa build`
#    2 VB derleme hatasini (BC30198) yakaladi. analyze/validate = statik lint, VB expression
#    derleme hatalarini KACIRIR -> sahte DONE. build = gercek MSBuild compile = tek otorite
#    (ADR-0001/0007). build basarisizsa Result=Failure + Message doner.
#    uip = npm .ps1 shim -> pwsh -Command "& uip ..." ile cozulur (kanitlanmis tek calisan yol).
#    Hata/timeout/parse-fail -> FAIL-OPEN.
$clean = $false
$blocked = $false
$blockDetail = ""
try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "pwsh"
    $cmd = "& uip rpa build '$projDir' --output json"
    $psi.Arguments = "-NoProfile -Command `"$cmd`""
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    # KRITIK: hem stdout HEM stderr async drain. build stderr'e [ERROR]/[Process] yazar;
    # bosaltilmazsa buffer dolar -> process bloke -> timeout.
    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderrTask = $proc.StandardError.ReadToEndAsync()
    if (-not $proc.WaitForExit(180000)) {   # build analyze'dan agir -> 180sn
        try { $proc.Kill() } catch {}
        exit 0   # timeout -> FAIL-OPEN
    }
    $stdout = $stdoutTask.Result
    $null = $stderrTask.Result   # drain
    # SAVUNMACI: stdout'ta JSON onunde/arkasinda log olabilir -> ilk { ... son } ayikla.
    $s = $stdout.IndexOf('{'); $e = $stdout.LastIndexOf('}')
    if ($s -ge 0 -and $e -gt $s) { $stdout = $stdout.Substring($s, $e - $s + 1) }
    $json = $stdout | ConvertFrom-Json
    # build: Result=Success -> temiz. Result=Failure -> derleme HATASI (blokla).
    if ($json.Result -eq "Success") { $clean = $true }
    elseif ($json.Result -eq "Failure") { $blocked = $true; $blockDetail = [string]$json.Message }
    # Belirsiz sema -> ne clean ne blocked -> FAIL-OPEN.
} catch {
    exit 0   # CLI/parse hatasi -> FAIL-OPEN
}

if ($blocked) {
    $reason = "DONE-gate: 'uip rpa build' DERLEME HATASI bildirdi. Is BITMEDI. " +
              "Detay: " + $blockDetail + " | Tam liste: 'uip rpa build " + $projDir + " --output json'. " +
              "NOT: analyze/validate bu hatalari KACIRIR (statik lint); build = gercek otorite. " +
              "Duzelt, sonra bitir. Duzeltemiyorsan kullaniciya soyle (Kural #5) — 'bitti' deme."
    [Console]::Error.WriteLine((@{ decision = "block"; reason = $reason } | ConvertTo-Json -Compress))
    exit 2
}

# Temiz (veya belirsiz->fail-open): is dogrulandi, flag'i temizle, gec.
if ($clean) { Remove-Item $flag -Force -ErrorAction SilentlyContinue }
exit 0
