param([string]$OutputDir = "D:\LumenIM-Packages\sysdeps")

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$webClient = New-Object System.Net.WebClient
$ErrorActionPreference = "Continue"

Write-Host "Download CentOS 7 system packages..." -ForegroundColor Cyan

$BaseUrl = "https://mirrors.ustc.edu.cn/centos-vault/7.9.2009/os/x86_64/Packages"
$EpelUrl = "https://mirrors.ustc.edu.cn/epel/7/x86_64/Packages"

$BasePkgs = @(
    "wget-1.14-18.el7_9.1.x86_64.rpm",
    "curl-7.61.1-9.el7.x86_64.rpm",
    "git-1.8.3.1-23.el7_9.x86_64.rpm",
    "unzip-6.0-24.el7.x86_64.rpm",
    "tar-1.27-17.el7.x86_64.rpm",
    "xz-5.2.2-2.el7.x86_64.rpm",
    "gcc-4.8.5-44.el7.x86_64.rpm",
    "gcc-c++-4.8.5-44.el7.x86_64.rpm",
    "make-3.82-29.el7.x86_64.rpm",
    "openssl-1.0.2k-25.el7_9.1.x86_64.rpm",
    "openssl-libs-1.0.2k-25.el7_9.1.x86_64.rpm",
    "net-tools-2.0-0.0.20161004git.el7.x86_64.rpm",
    "perl-5.16.3-299.el7_9.2.x86_64.rpm"
)

$EpelPkgs = @(
    "epel-release-7-14.noarch.rpm",
    "jq-1.6-2.el7.x86_64.rpm"
)

Write-Host "Downloading Base packages..." -ForegroundColor Yellow
$i = 0
foreach ($p in $BasePkgs) {
    $i++
    $path = Join-Path $OutputDir $p
    Write-Host "[$i/$($BasePkgs.Count)] $p..." -NoNewline
    try {
        $webClient.DownloadFile($BaseUrl + "/" + $p, $path)
        if ((Test-Path $path) -and (Get-Item $path).Length -gt 10000) {
            Write-Host " OK" -ForegroundColor Green
        } else {
            Write-Host " small file" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " fail" -ForegroundColor Red
    }
}

Write-Host "Downloading EPEL packages..." -ForegroundColor Yellow
$i = 0
foreach ($p in $EpelPkgs) {
    $i++
    $path = Join-Path $OutputDir $p
    Write-Host "[$i/$($EpelPkgs.Count)] $p..." -NoNewline
    try {
        $webClient.DownloadFile($EpelUrl + "/" + $p, $path)
        if ((Test-Path $path) -and (Get-Item $path).Length -gt 1000) {
            Write-Host " OK" -ForegroundColor Green
        } else {
            Write-Host " small file" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " fail" -ForegroundColor Red
    }
}

$webClient.Dispose()

Write-Host ""
Write-Host "Done. Files in:" -ForegroundColor Cyan -NoNewline
Write-Host " $OutputDir" -ForegroundColor White
Get-ChildItem -Path $OutputDir -File | ForEach-Object {
    $s = [math]::Round($_.Length / 1048576, 2)
    Write-Host "  $($_.Name) $s MB"
}