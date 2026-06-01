# guard-shell.ps1 — Cursor beforeShellExecution hook
# .xaml dosyasina SHELL ile yazma/duzenleme girisimini HARD-BLOCK eder.
# Kural #3: her XAML degisikligi edit_workflow MCP ile; elle/shell yazma YASAK.
# Kontrat: stdin JSON {command, cwd, ...} -> stdout JSON {permission: allow|deny, agent_message, user_message}
#
# Sadece YAZMA engellenir; okuma (cat/Get-Content/grep/Select-String) serbest.

$ErrorActionPreference = "SilentlyContinue"
$raw = @($input) -join "`n"
if (-not $raw) { $raw = [Console]::In.ReadToEnd() }
try { $in = $raw | ConvertFrom-Json } catch { '{"permission":"allow"}'; exit 0 }
$cmd = [string]$in.command
if (-not $cmd) { '{"permission":"allow"}'; exit 0 }

# .xaml'a yazma desenleri (redirect / cmdlet / sed / tee)
$writePatterns = @(
    '>\s*[''"]?[^''"\|&]*\.xaml'                 # echo ... > Main.xaml  /  >> Main.xaml
    'Set-Content[^\|]*\.xaml'
    'Add-Content[^\|]*\.xaml'
    'Out-File[^\|]*\.xaml'
    'Tee-Object[^\|]*\.xaml'
    '\bsed\b[^\|]*-i[^\|]*\.xaml'
    '\bsed\b[^\|]*\.xaml[^\|]*-i'
    'New-Item[^\|]*\.xaml[^\|]*-Force'
)
foreach ($p in $writePatterns) {
    if ($cmd -match $p) {
        $msg = "BLOCKED: .xaml dosyasina shell ile yazma YASAK (Kural #3). " +
               "Her XAML degisikligi edit_workflow MCP tool'u ile yapilir (xmlns auto-inject + .bak). " +
               "MCP calismiyorsa once onu duzelt; etrafindan dolasma."
        @{ permission = "deny"; agent_message = $msg; user_message = "uipath-mcp-plugin: elle .xaml yazma engellendi -> edit_workflow kullan" } | ConvertTo-Json -Compress
        exit 0
    }
}
'{"permission":"allow"}'
exit 0
