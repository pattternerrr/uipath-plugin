# publish-bins.ps1 — DEV-ONLY
# UiPathMCP (net8) + StudioBridge (net8) derleyip plugin'in bin/ klasörüne yerleştirir.
# Arkadaşlar bunu ÇALIŞTIRMAZ — bin/ git'e commit'li gelir. Bu script sadece bin/'i
# yeniden üretmek (kod değişince) içindir.
#
# net8 SDK gerekir. Sistem dotnet'i net7 ise user-scoped (~/.dotnet) net8 SDK kullanılır.

$ErrorActionPreference = "Stop"

$repo = "C:\Users\mustafa.basar\Documents\UiPath\mcp-csharp"
$binOut = Join-Path $PSScriptRoot "..\bin"
$binOut = [System.IO.Path]::GetFullPath($binOut)

# net8 yapabilen dotnet'i bul: önce user-scoped, sonra sistem.
$userDotnet = Join-Path $env:USERPROFILE ".dotnet\dotnet.exe"
$dotnet = if (Test-Path $userDotnet) {
    $sdks = & $userDotnet --list-sdks
    if ($sdks -match "^8\.") { $userDotnet } else { "dotnet" }
} else { "dotnet" }
Write-Host "dotnet: $dotnet"

# Çalışan MCP varsa kilit açmak için durdur.
Get-Process -Name UiPathMCP -ErrorAction SilentlyContinue | Stop-Process -Force -Confirm:$false
Start-Sleep -Seconds 1

# bin/ temizle (.gitkeep koru).
if (Test-Path $binOut) {
    Get-ChildItem $binOut -Exclude ".gitkeep" | Remove-Item -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $binOut | Out-Null
}

Write-Host "=== 1/3 StudioBridge build (net8, UiPath DLL'leri Studio'dan runtime'da yüklenir) ==="
& $dotnet build "$repo\StudioBridge\StudioBridge.csproj" -c Release
if ($LASTEXITCODE -ne 0) { throw "StudioBridge build başarısız" }

Write-Host "=== 2/3 UiPathMCP publish (net8, self-contained — arkadaşlar runtime kurmaz) ==="
# SINGLE-FILE DEĞİL: MetadataLoadContext, runtime CoreLib DLL'lerini DİSKTE dosya olarak
# arar (typeof(object).Assembly.Location). Single-file'da o yol "" döner → reflection çöker.
# Self-contained + çok dosya = tüm runtime DLL'leri bin/'de durur → reflection çalışır,
# arkadaş yine runtime kurmaz. Bedeli: ~200 dosya / ~90MB.
& $dotnet publish "$repo\UiPathMCP.csproj" -c Release -r win-x64 --self-contained true -o $binOut
if ($LASTEXITCODE -ne 0) { throw "UiPathMCP publish başarısız" }

Write-Host "=== 3/3 StudioBridge dll + runtimeconfig kopyala (exe DEĞİL — Studio'nun dotnet exec'i çalıştırır) ==="
$bridgeDir = "$repo\StudioBridge\bin\Release\net8.0-windows"
foreach ($f in @("UiPathStudioBridge.dll", "UiPathStudioBridge.runtimeconfig.json", "UiPathStudioBridge.deps.json")) {
    $src = Join-Path $bridgeDir $f
    if (Test-Path $src) { Copy-Item $src $binOut -Force; Write-Host "  + $f" }
}

# Publish gereksizleri temizle (boyut küçült).
Get-ChildItem $binOut -Include "*.pdb" -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue

Write-Host "`n=== bin/ içeriği ==="
Get-ChildItem $binOut | Select-Object Name, @{N='KB';E={[math]::Round($_.Length/1KB,1)}} | Format-Table -AutoSize
$total = (Get-ChildItem $binOut -Recurse | Measure-Object Length -Sum).Sum / 1MB
Write-Host ("Toplam: {0:N2} MB" -f $total)
Write-Host "TAMAM. UiPathMCP.exe + UiPathStudioBridge.dll hazır."
