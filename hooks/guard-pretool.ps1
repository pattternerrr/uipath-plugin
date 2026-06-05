# guard-pretool.ps1 — Claude Code PreToolUse HARD-BLOCK
# Kural #3: .xaml'a elle dokunma YASAK -> sadece edit_workflow MCP tool'u.
#   - Edit/Write/MultiEdit  : file_path .xaml ise DENY
#   - Bash                  : komut .xaml'a yaziyorsa DENY (redirect/Set-Content/Out-File/sed -i...)
# Okuma (Get-Content/cat/grep/Read) serbest. Sifir CLI riski — yalnizca yazma niyetini engeller.
#
# Kontrat (dokumante): blokla -> stderr'e {"decision":"deny","reason":...} + exit 2; izin -> exit 0.
# stdin JSON: { tool_name, tool_input: { file_path?, command? }, ... }

$ErrorActionPreference = "SilentlyContinue"
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }   # girdi yoksa karisma

# HIZLI YOL: komut/dosya '.xaml' icermiyorsa hicbir kural tetiklenemez -> JSON parse +
# regex'i ATLA, aninda gec. Cogu Bash/Edit cagrisi buradan ucuza cikar (~0.45s tasarruf).
if ($raw -notmatch '\.xaml') { exit 0 }

try { $in = $raw | ConvertFrom-Json } catch { exit 0 }

$tool = [string]$in.tool_name

function Deny([string]$reason) {
    [Console]::Error.WriteLine((@{ decision = "deny"; reason = $reason } | ConvertTo-Json -Compress))
    exit 2
}

$denyMsg = "BLOCKED (Kural #3): .xaml'a elle yazma YASAK. Her XAML degisikligi " +
           "`edit_workflow` MCP tool'u ile yapilir (xmlns auto-inject + .bak yedek). " +
           "MCP calismiyorsa once onu duzelt; etrafindan dolasma (Kural #1/#5)."

switch -Regex ($tool) {
    'Edit|Write|MultiEdit' {
        $fp = [string]$in.tool_input.file_path
        if ($fp -match '\.xaml$') { Deny $denyMsg }
        exit 0
    }
    'Bash' {
        $cmd = [string]$in.tool_input.command
        if (-not $cmd) { exit 0 }
        $writePatterns = @(
            '>\s*[''"]?[^''"\|&]*\.xaml'      # echo ... > Main.xaml / >> Main.xaml
            'Set-Content[^\|]*\.xaml'
            'Add-Content[^\|]*\.xaml'
            'Out-File[^\|]*\.xaml'
            'Tee-Object[^\|]*\.xaml'
            '\bsed\b[^\|]*-i[^\|]*\.xaml'
            '\bsed\b[^\|]*\.xaml[^\|]*-i'
            'New-Item[^\|]*\.xaml[^\|]*-Force'
            '\[IO\.File\]::WriteAllText[^\r\n]*\.xaml'
            'Out-File[^\|]*\.xaml'
        )
        foreach ($p in $writePatterns) {
            if ($cmd -match $p) { Deny $denyMsg }
        }
        exit 0
    }
    default { exit 0 }
}
