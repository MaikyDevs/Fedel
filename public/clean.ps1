& {
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
cls

Write-Host ''
Write-Host '  ==================================================' -ForegroundColor Cyan
Write-Host '   ______           _                               ' -ForegroundColor Cyan
Write-Host '  |  ____|         | |                              ' -ForegroundColor Cyan
Write-Host '  | |__   _ __   __| | _____      ____ _ _ __ ___   ' -ForegroundColor Cyan
Write-Host '  |  __| | |_ \ / _` |/ _ \ \ /\ / / _` | |_ ` _ \  ' -ForegroundColor Cyan
Write-Host '  | |____| | | | (_| | (_) \ V  V / (_| | | | | | | ' -ForegroundColor Cyan
Write-Host '  |______|_| |_|\__,_|\___/ \_/\_/ \__,_|_| |_| |_| ' -ForegroundColor Cyan
Write-Host '  ==================================================' -ForegroundColor Cyan
Write-Host '   Steam GreenLuma cleanup script                    ' -ForegroundColor Gray
Write-Host '   Deletes stplug-in contents + depotcache contents  ' -ForegroundColor DarkGray
Write-Host '  ==================================================' -ForegroundColor Cyan
Write-Host ''

$ok = [char]0x2713

function Fail($msg) {
    Write-Host "  [X] $msg" -ForegroundColor Red
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

# Locate Steam install from registry
$steamPath = $null
foreach ($reg in @('HKCU:\Software\Valve\Steam','HKLM:\Software\Valve\Steam','HKLM:\Software\WOW6432Node\Valve\Steam')) {
    $p = (Get-ItemProperty -Path $reg -EA SilentlyContinue).SteamPath
    if ($p -and (Test-Path ($p -replace '/','\'))){ $steamPath = $p -replace '/','\'; break }
}
if (-not $steamPath) { Fail 'Steam not found on this system.' }
Write-Host "  $ok Found Steam: $steamPath" -ForegroundColor Green

# Target directories
$targets = @(
    @{ Name = 'config\stplug-in (DLL + lua drop folder)'; Path = (Join-Path $steamPath 'config\stplug-in') },
    @{ Name = 'depotcache (manifest cache)';              Path = (Join-Path $steamPath 'depotcache') }
)

Write-Host ''
Write-Host '  Closing Steam before cleanup...' -ForegroundColor Yellow
CloseSteam $steamPath

Write-Host ''
Write-Host '  Cleaning directories:' -ForegroundColor White
$totalRemoved = 0
$hadErrors = $false

foreach ($t in $targets) {
    Write-Host ''
    Write-Host "  -> $($t.Name)" -ForegroundColor Cyan
    Write-Host "     $($t.Path)" -ForegroundColor DarkGray

    if (-not (Test-Path -LiteralPath $t.Path)) {
        Write-Host "     - absent (nothing to clean)" -ForegroundColor DarkGray
        continue
    }

    $items = Get-ChildItem -LiteralPath $t.Path -Force -EA SilentlyContinue
    if (-not $items -or $items.Count -eq 0) {
        Write-Host "     - empty (nothing to clean)" -ForegroundColor DarkGray
        continue
    }

    $removed = 0
    $failed  = 0
    foreach ($item in $items) {
        try {
            Remove-Item -LiteralPath $item.FullName -Recurse -Force -EA Stop
            $removed++
        } catch {
            $failed++
            $hadErrors = $true
            Write-Host "     ! failed: $($item.Name) - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Write-Host "     $ok removed $removed item(s)" -ForegroundColor Green
    $totalRemoved += $removed
}

Write-Host ''
if ($hadErrors) {
    Write-Host "  ! Done. Removed $totalRemoved item(s), some items could not be removed." -ForegroundColor Yellow
} else {
    Write-Host "  $ok Done. Removed $totalRemoved item(s)." -BackgroundColor Green -ForegroundColor Black
}

Start-Process (Join-Path $steamPath 'steam.exe')
Write-Host "  $ok Started Steam" -ForegroundColor Green

Write-Host ''
Write-Host '  Press any key to exit...' -ForegroundColor DarkGray
try { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch { Start-Sleep 10 }
}
