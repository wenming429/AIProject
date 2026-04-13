param(
    [string]$OutputDir = "D:\LumenIM-Packages"
)

$ErrorActionPreference = "Continue"
$webClient = New-Object System.Net.WebClient

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "下载缺失的离线包" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Go
Write-Host "[1/4] 下载 Go 1.21.14..." -ForegroundColor Yellow
$goUrl = "https://go.dev/dl/go1.21.14.linux-amd64.tar.gz"
$goPath = Join-Path $OutputDir "go1.21.14.linux-amd64.tar.gz"
try {
    $webClient.DownloadFile($goUrl, $goPath)
    $size = (Get-Item $goPath).Length
    $mb = [math]::Round($size / 1048576, 2)
    Write-Host "  完成 ($mb MB)" -ForegroundColor Green
} catch {
    Write-Host "  失败: " -ForegroundColor Red
}

# 2. containerd.io (版本 1.6.33)
Write-Host "[2/4] 下载 containerd.io 1.6.33..." -ForegroundColor Yellow
$url1 = "https://download.docker.com/linux/centos/7/x86_64/stable/Packages/containerd.io-1.6.33-3.1.el7.x86_64.rpm"
$path1 = Join-Path (Join-Path $OutputDir "docker") "containerd.io-1.6.33-3.1.el7.x86_64.rpm"
try {
    $webClient.DownloadFile($url1, $path1)
    $size = (Get-Item $path1).Length
    $mb = [math]::Round($size / 1048576, 2)
    Write-Host "  完成 ($mb MB)" -ForegroundColor Green
} catch {
    Write-Host "  失败" -ForegroundColor Red
}

# 3. docker-ce (版本 26.1.4-1)
Write-Host "[3/4] 下载 docker-ce 26.1.4..." -ForegroundColor Yellow
$url2 = "https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-26.1.4-1.el7.x86_64.rpm"
$path2 = Join-Path (Join-Path $OutputDir "docker") "docker-ce-26.1.4-1.el7.x86_64.rpm"
try {
    $webClient.DownloadFile($url2, $path2)
    $size = (Get-Item $path2).Length
    $mb = [math]::Round($size / 1048576, 2)
    Write-Host "  完成 ($mb MB)" -ForegroundColor Green
} catch {
    Write-Host "  失败" -ForegroundColor Red
}

# 4. docker-ce-cli (版本 26.1.4-1)
Write-Host "[4/4] 下载 docker-ce-cli 26.1.4..." -ForegroundColor Yellow
$url3 = "https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-cli-26.1.4-1.el7.x86_64.rpm"
$path3 = Join-Path (Join-Path $OutputDir "docker") "docker-ce-cli-26.1.4-1.el7.x86_64.rpm"
try {
    $webClient.DownloadFile($url3, $path3)
    $size = (Get-Item $path3).Length
    $mb = [math]::Round($size / 1048576, 2)
    Write-Host "  完成 ($mb MB)" -ForegroundColor Green
} catch {
    Write-Host "  失败" -ForegroundColor Red
}

$webClient.Dispose()

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "下载完成" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan