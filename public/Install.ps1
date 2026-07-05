& {
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
cls

Write-Host ''
Write-Host '  ███████╗███████╗██████╗ ███████╗██╗     ' -ForegroundColor Cyan
Write-Host '  ██╔════╝██╔════╝██╔══██╗██╔════╝██║     ' -ForegroundColor Cyan
Write-Host '  █████╗  █████╗  ██║  ██║█████╗  ██║     ' -ForegroundColor Cyan
Write-Host '  ██╔══╝  ██╔══╝  ██║  ██║██╔══╝  ██║     ' -ForegroundColor Cyan
Write-Host '  ██║     ███████╗██████╔╝███████╗███████╗' -ForegroundColor Cyan
Write-Host '  ╚═╝     ╚══════╝╚═════╝ ╚══════╝╚══════╝' -ForegroundColor Cyan
Write-Host ''
Write-Host '  Fedel Installer - Ultimate Steam Manifest Fix' -ForegroundColor White
Write-Host '  Download-Server: https://fedel.violt.de' -ForegroundColor DarkGray
Write-Host ''

# Force TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::DefaultConnectionLimit = 16
[Net.ServicePointManager]::Expect100Continue = $false

$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36'
$ok = [char]0x2713
$dllUrl = 'https://fedel.violt.de/wtsapi32.dll'

function Fail($msg) {
    Write-Host "  X $msg" -ForegroundColor Red
    Write-Host ''; Write-Host '  Press any key to exit...' -ForegroundColor DarkGray
    try { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch { Start-Sleep 10 }
    exit
}

function CloseSteam {
    if (-not (Get-Process -Name steam -EA SilentlyContinue)) { return }
    $steamExe = Join-Path $steamPath 'steam.exe'
    if (Test-Path $steamExe) { Start-Process $steamExe -ArgumentList '-shutdown' -EA SilentlyContinue }
    for ($i = 0; $i -lt 15; $i++) {
        if (-not (Get-Process -Name steam -EA SilentlyContinue)) { break }
        Start-Sleep 1
    }
    Get-Process -Name steam,steamwebhelper,steamservice -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
    Start-Sleep 2
    if (Get-Process -Name steam -EA SilentlyContinue) { Fail 'Could not close Steam. Kill that shit manually.' }
    Write-Host "  $ok Closed Steam" -ForegroundColor Green
}

$steamPath = $null
foreach ($reg in @('HKCU:\Software\Valve\Steam','HKLM:\Software\Valve\Steam','HKLM:\Software\WOW6432Node\Valve\Steam')) {
    $p = (Get-ItemProperty -Path $reg -EA SilentlyContinue).SteamPath
    if ($p -and (Test-Path ($p -replace '/','\'))){ $steamPath = $p -replace '/','\'; break }
}
if (-not $steamPath) { Fail 'Steam not found in Registry.' }
Write-Host "  $ok Found Steam at $steamPath" -ForegroundColor Green

$steamExe = Join-Path $steamPath 'steam.exe'
try {
    $bytes = [System.IO.File]::ReadAllBytes($steamExe)
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
    $machine = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
    if ($machine -ne 0x8664) {
        Write-Host "  ! Steam is fucking 32-bit, attempting fix..." -ForegroundColor Yellow
        Remove-Item (Join-Path $steamPath 'steam.cfg') -Force -EA SilentlyContinue
        Remove-Item (Join-Path $steamPath 'package\beta') -Force -Recurse -EA SilentlyContinue
        CloseSteam
        Start-Process $steamExe
        Fail 'Removed update blocking files. Steam will update to 64-bit now. Rerun the installer later.'
    }
} catch {
    Fail "Could not verify Steam architecture: $($_.Exception.Message)"
}
Write-Host "  $ok Steam architecture is 64-bit" -ForegroundColor Green

$dest = Join-Path $steamPath 'wtsapi32.dll'
$cleanup = @(
    (Join-Path $steamPath 'version.dll'),
    (Join-Path $steamPath 'config\manifests.dll'),
    (Join-Path $steamPath 'config\.mfx_init'),
    (Join-Path $steamPath 'config\.stfix_init')
)

CloseSteam
$cleanup | ForEach-Object { Remove-Item $_ -Force -EA SilentlyContinue }
Remove-Item $dest -Force -EA SilentlyContinue

$sw = [System.Diagnostics.Stopwatch]::StartNew()

try {
    $req = [System.Net.HttpWebRequest]::Create($dllUrl)
    $req.UserAgent = $UA
    $req.Timeout = 15000
    $req.ReadWriteTimeout = 15000
    $req.KeepAlive = $true
    $req.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
    $resp = $req.GetResponse()
    $total = $resp.ContentLength

    $stream = $resp.GetResponseStream()
    $buffered = New-Object System.IO.BufferedStream($stream, 1048576)
    $fs = [System.IO.FileStream]::new($dest, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None, 1048576)

    $buf = New-Object byte[] 1048576
    $dl = 0
    $lastProgress = 0

    while (($n = $buffered.Read($buf, 0, $buf.Length)) -gt 0) {
        $fs.Write($buf, 0, $n)
        $dl += $n
        if ($total -gt 0 -and ($dl - $lastProgress) -gt 32768) {
            $pct = [math]::Floor(($dl / $total) * 100)
            $filled = [math]::Floor(($dl / $total) * 25)
            $bar = "$([char]0x2588)" * $filled + "$([char]0x2591)" * (25 - $filled)
            $speed = if ($sw.Elapsed.TotalSeconds -gt 0) { $dl / $sw.Elapsed.TotalSeconds / 1MB } else { 0 }
            Write-Host "`r  Downloading DLL  $bar  $('{0:N1}' -f ($dl/1KB))/$('{0:N1}' -f ($total/1KB)) KB  $('{0:N1}' -f $speed) MB/s  " -NoNewline -ForegroundColor Cyan
            $lastProgress = $dl
        }
    }

    $fs.Flush()
    $fs.Close()
    $buffered.Close()
    $stream.Close()
    $resp.Close()

    $sw.Stop()
    Write-Host "`r  $ok Downloaded Fedel DLL ($('{0:N1}' -f ($dl/1KB)) KB) in $('{0:N1}' -f $sw.Elapsed.TotalSeconds)s$(' ' * 30)" -ForegroundColor Green
} catch {
    Fail "Download failed fucked up: $($_.Exception.Message)"
}
if (-not (Test-Path $dest)) { Fail 'File was not saved on disk.' }

Start-Process $steamExe
Write-Host "  $ok Started Steam" -ForegroundColor Green

Write-Host ''
Write-Host "  $ok Fedel Manifest fix successfully installed!" -BackgroundColor Cyan -ForegroundColor Black
Write-Host ''
Write-Host '  Press any key to exit...' -ForegroundColor DarkGray
try { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch { Start-Sleep 10 }
}
