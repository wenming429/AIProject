param(
    [string]$OutputDir = "D:\LumenIM-Packages"
)

$ErrorActionPreference = "Continue"
$webClient = New-Object System.Net.WebClient

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "下载 Go 1.21.14" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 尝试多个镜像源
$mirrors = @(
    "https://mirrors.ustc.edu.cn/golang/go1.21.14.linux-amd64.tar.gz",
    "https://dl.google.com/go/go1.21.14.linux-amd64.tar.gz"
)

$success = $false
foreach ($url in $mirrors) {
    Write-Host "尝试: " -ForegroundColor Yellow -NoNewline
    Write-Host $url -ForegroundColor White
    $goPath = Join-Path $OutputDir "go1.21.14.linux-amd64.tar.gz"
    try {
        $webClient.DownloadFile($url, $goPath)
        $size = (Get-Item $goPath).Length
        if ($size -gt 10000000) {
            $mb = [math]::Round($size / 1048576, 2)
            Write-Host "  完成 ($mb MB)" -ForegroundColor Green
            $success = $true
            break
        }
    } catch {
        Write-Host "  失败" -ForegroundColor Red
    }
}

if (-not $success) {
    Write-Host ""
    Write-Host "所有镜像均失败，请手动下载" -ForegroundColor Red
    Write-Host "URL: https://go.dev/dl/go1.21.14.linux-amd64.tar.gz" -ForegroundColor Yellow
}

$webClient.Dispose()