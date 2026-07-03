& {
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
cls

Write-Host ''
Write-Host '  ===========================================' -ForegroundColor Cyan
Write-Host '   _____ _____ ____  _____    _     _       ' -ForegroundColor Cyan
Write-Host '  |   __|   __|    \|   __|  | |   | |      ' -ForegroundColor Cyan
Write-Host '  |   __|   __|  |  |   __|  | |__ | |__    ' -ForegroundColor Cyan
Write-Host '  |__|  |____|____/|_____|  |____||____|   ' -ForegroundColor Cyan
Write-Host '  ===========================================' -ForegroundColor Cyan
Write-Host '   Reverts the Steamproof manifest fix       ' -ForegroundColor Gray
Write-Host '   Removes sideloaded wtsapi32.dll + traces  ' -ForegroundColor DarkGray
Write-Host '  ===========================================' -ForegroundColor Cyan
Write-Host ''

$ok = [char]0x2713

function Fail($msg) {
    Write-Host "  X $msg" -ForegroundColor Red
    Write-Host ''; Write-Host '  Press any key to exit...' -ForegroundColor DarkGray
    try { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch { Start-Sleep 10 }
    exit
}

function CloseSteam($steamPath) {
    if (-not (Get-Process -Name steam -EA SilentlyContinue)) { return }
    $steamExe = Join-Path $steamPath 'steam.exe'
    if (Test-Path $steamExe) { Start-Process $steamExe -ArgumentList '-shutdown' -EA SilentlyContinue }
    for ($i = 0; $i -lt 15; $i++) {
        if (-not (Get-Process -Name steam -EA SilentlyContinue)) { break }
        Start-Sleep 1
    }
    Get-Process -Name steam,steamwebhelper,steamservice -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
    Start-Sleep 2
    if (Get-Process -Name steam -EA SilentlyContinue) { Fail 'Could not close Steam. Please close it manually and try again.' }
    Write-Host "  $ok Closed Steam" -ForegroundColor Green
}

$steamPath = $null
foreach ($reg in @('HKCU:\Software\Valve\Steam','HKLM:\Software\Valve\Steam','HKLM:\Software\WOW6432Node\Valve\Steam')) {
    $p = (Get-ItemProperty -Path $reg -EA SilentlyContinue).SteamPath
    if ($p -and (Test-Path ($p -replace '/','\'))){ $steamPath = $p -replace '/','\'; break }
}
if (-not $steamPath) { Fail 'Steam not found' }
Write-Host "  $ok Found Steam: $steamPath" -ForegroundColor Green

$targets = @(
    @{ Name = 'wtsapi32.dll (sideloaded payload)'; Path = (Join-Path $steamPath 'wtsapi32.dll') },
    @{ Name = 'version.dll (legacy sideload)';     Path = (Join-Path $steamPath 'version.dll') },
    @{ Name = 'config\manifests.dll';              Path = (Join-Path $steamPath 'config\manifests.dll') },
    @{ Name = 'config\.mfx_init (init marker)';    Path = (Join-Path $steamPath 'config\.mfx_init') },
    @{ Name = 'config\.stfix_init (init marker)';  Path = (Join-Path $steamPath 'config\.stfix_init') }
)

$foundAny = $false
foreach ($t in $targets) { if (Test-Path $t.Path) { $foundAny = $true; break } }

if (-not $foundAny) {
    Write-Host ''
    Write-Host "  $ok No Steamproof traces found. Steam is clean." -ForegroundColor Green
    Write-Host ''; Write-Host '  Press any key to exit...' -ForegroundColor DarkGray
    try { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch { Start-Sleep 10 }
    exit
}

Write-Host ''
Write-Host '  Closing Steam before cleanup...' -ForegroundColor Yellow
CloseSteam $steamPath

Write-Host ''
Write-Host '  Removing Steamproof footprint:' -ForegroundColor White
$removed = 0
$skipped = 0
foreach ($t in $targets) {
    if (Test-Path $t.Path) {
        try {
            Remove-Item $t.Path -Force -EA Stop
            Write-Host "    $ok removed  $($t.Name)" -ForegroundColor Green
            $removed++
        } catch {
            Write-Host "    ! failed   $($t.Name) - $($_.Exception.Message)" -ForegroundColor Red
            $skipped++
        }
    } else {
        Write-Host "    - absent   $($t.Name)" -ForegroundColor DarkGray
    }
}

Write-Host ''
if ($skipped -gt 0) {
    Write-Host "  ! Done. Removed $removed, $skipped could not be removed." -ForegroundColor Yellow
} else {
    Write-Host "  $ok Done. Removed $removed file(s). Steamproof has been reverted." -BackgroundColor Green -ForegroundColor Black
}

Start-Process (Join-Path $steamPath 'steam.exe')
Write-Host "  $ok Started Steam (clean)" -ForegroundColor Green

Write-Host ''
Write-Host '  Press any key to exit...' -ForegroundColor DarkGray
try { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch { Start-Sleep 10 }
}
