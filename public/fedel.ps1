# =============================================
# fedelfix - Manifest Fix for SteamTools
# Optimized for better Steam download & performance
# =============================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

Write-Host ''
Write-Host "   _____       _     _ _ _     _ " -ForegroundColor Cyan
Write-Host "  |  ___|__  _| |__ | | | |__ (_)" -ForegroundColor Cyan
Write-Host "  | |_ / _ \/ _`  |/ _`  | '_ \| |" -ForegroundColor Cyan
Write-Host "  |  _|  __/ (_| | (_| | | | | |" -ForegroundColor Cyan
Write-Host "  |_|  \___|\__,_|\__,_|_| |_|_|" -ForegroundColor Cyan
Write-Host ''
Write-Host '          fedelfix - Manifest Fix' -ForegroundColor Gray
Write-Host '          Optimized for Steam Performance' -ForegroundColor DarkGray
Write-Host ''

$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36'
$ok = [char]0x2713
$fixUrl = 'https://r2.steamproof.net/update'
$fixDll = 'wtsapi32.dll'

function Fail($msg) {
    Write-Host " X $msg" -ForegroundColor Red
    Write-Host "`n Drücke eine Taste zum Beenden..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
}

function CloseSteam {
    Write-Host " Schließe Steam-Prozesse..." -ForegroundColor Yellow -NoNewline
    Get-Process -Name 'steam','steamwebhelper','steamservice','steamupdate' -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
    Start-Sleep 3
    Write-Host " $ok" -ForegroundColor Green
}

# Steam Pfad finden
$steamPath = $null
foreach ($reg in @('HKCU:\Software\Valve\Steam','HKLM:\Software\Valve\Steam','HKLM:\Software\WOW6432Node\Valve\Steam')) {
    try {
        $p = (Get-ItemProperty -Path $reg -EA SilentlyContinue).SteamPath
        if ($p) {
            $p = $p -replace '/', '\'
            if (Test-Path $p) { $steamPath = $p; break }
        }
    } catch {}
}
if (-not $steamPath) { Fail 'Steam-Installation nicht gefunden.' }

Write-Host " $ok Steam gefunden: $steamPath" -ForegroundColor Green

$dest = Join-Path $steamPath $fixDll

# Cleanup (sanfter als vorher)
$cleanupPaths = @(
    (Join-Path $steamPath 'config\.mfx_init'),
    (Join-Path $steamPath 'config\.stfix_init')
)
$cleanupPaths | ForEach-Object { Remove-Item $_ -Force -EA SilentlyContinue }

# 64-Bit Check
$steamExe = Join-Path $steamPath 'steam.exe'
# ... (64-Bit Teil bleibt gleich wie vorher) ...

# Download des Fixes
$needsUpdate = $true
if (Test-Path $dest) {
    try {
        $localHash = (Get-FileHash $dest -Algorithm MD5).Hash.ToLower()
        $req = [System.Net.HttpWebRequest]::Create($fixUrl)
        $req.Method = 'HEAD'
        $req.UserAgent = $UA
        $remoteEtag = $req.GetResponse().Headers['ETag'] -replace '"',''
        if ($remoteEtag -and $localHash -eq $remoteEtag) {
            $needsUpdate = $false
        }
    } catch {}
}

if ($needsUpdate) {
    CloseSteam
    Remove-Item $dest -Force -EA SilentlyContinue
    Write-Host " Lade neues Manifest-Fix..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $fixUrl -OutFile $dest -UserAgent $UA -UseBasicParsing
        Write-Host " $ok Fix heruntergeladen" -ForegroundColor Green
    } catch {
        Fail "Download fehlgeschlagen"
    }
}

# Steam Performance Optimierungen
CloseSteam

# Kleiner Steam-Cache Cleanup für bessere Download-Performance
$cacheFolder = Join-Path $steamPath 'appcache'
if (Test-Path $cacheFolder) {
    Remove-Item (Join-Path $cacheFolder 'httpcache') -Recurse -Force -EA SilentlyContinue
    Remove-Item (Join-Path $cacheFolder 'shadercache') -Recurse -Force -EA SilentlyContinue
}

# Steam starten
Write-Host " Starte Steam mit Optimierungen..." -ForegroundColor Cyan
$steamArgs = @('-no-browser', '-silent')   # Weniger Lag durch Browser-Integration
Start-Process $steamExe -ArgumentList $steamArgs

if ($needsUpdate) {
    Write-Host "`n $ok fedelfix erfolgreich installiert!" -BackgroundColor Green -ForegroundColor Black
} else {
    Write-Host "`n $ok fedelfix ist bereits aktuell!" -BackgroundColor Green -ForegroundColor Black
}

Write-Host "`n Tipp: Warte 10-20 Sekunden nach dem Start, bevor du Downloads startest." -ForegroundColor Yellow
Write-Host "`n Drücke eine Taste zum Beenden..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')