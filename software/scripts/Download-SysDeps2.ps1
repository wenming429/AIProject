param([string]$OutputDir = "D:\LumenIM-Packages\sysdeps")

$webClient = New-Object System.Net.WebClient
$ErrorActionPreference = "Continue"

Write-Host "Try multiple mirrors..." -ForegroundColor Cyan

$BaseMirrors = @(
    "https://mirrors.tuna.tsinghua.edu.cn/centos-vault/7.9.2009/os/x86_64/Packages/",
    "https://mirrors.aliyun.com/centos-vault/7.9.2009/os/x86_64/Packages/",
    "https://vault.centos.org/7.9.2009/os/x86_64/Packages/"
)

$BasePkgs = @(
    "wget-1.14-18.el7_9.1.x86_64.rpm",
    "curl-7.61.1-9.el7.x86_64.rpm",
    "tar-1.27-17.el7.x86_64.rpm",
    "xz-5.2.2-2.el7.x86_64.rpm",
    "make-3.82-29.el7.x86_64.rpm",
    "openssl-1.0.2k-25.el7_9.1.x86_64.rpm",
    "openssl-libs-1.0.2k-25.el7_9.1.x86_64.rpm",
    "net-tools-2.0-0.0.20161004git.el7.x86_64.rpm",
    "git-1.8.3.1-23.el7_9.x86_64.rpm",
    "unzip-6.0-24.el7.x86_64.rpm",
    "perl-5.16.3-299.el7_9.2.x86_64.rpm",
    "epel-release-7-14.noarch.rpm",
    "jq-1.6-2.el7.x86_64.rpm"
)

$found = 0

foreach ($mirror in $BaseMirrors) {
    Write-Host "Testing: $mirror" -ForegroundColor Yellow
    $testUrl = $mirror + "wget-1.14-18.el7_9.1.x86_64.rpm"
    $testPath = Join-Path $OutputDir "test.rpm"
    try {
        $webClient.DownloadFile($testUrl, $testPath)
        if ((Test-Path $testPath) -and (Get-Item $testPath).Length -gt 10000) {
            Write-Host "  Mirror OK, downloading packages..." -ForegroundColor Green
            $found = 1
            Remove-Item $testPath -Force

            $i = 0
            foreach ($pkg in $BasePkgs) {
                $i++
                $path = Join-Path $OutputDir $pkg
                if ((Test-Path $path) -and (Get-Item $path).Length -gt 5000) {
                    Write-Host "  [$i] $pkg exists" -ForegroundColor Green
                    continue
                }
                Write-Host "  [$i/$($BasePkgs.Count)] $pkg..." -NoNewline
                try {
                    $webClient.DownloadFile($mirror + $pkg, $path)
                    if ((Test-Path $path) -and (Get-Item $path).Length -gt 5000) {
                        Write-Host " OK" -ForegroundColor Green
                    } else {
                        Write-Host " small" -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host " fail" -ForegroundColor Red
                }
            }
            break
        }
    } catch {
        Write-Host "  fail" -ForegroundColor Red
    }
}

$webClient.Dispose()

Write-Host ""
Write-Host "Downloaded files:" -ForegroundColor Cyan
Get-ChildItem -Path $OutputDir -File | ForEach-Object {
    $s = [math]::Round($_.Length / 1048576, 2)
    Write-Host "  $($_.Name) $s MB"
}