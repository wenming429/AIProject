param(
    [string]$OutputDir = ".\packages",
    [switch]$Go,
    [switch]$Node,
    [switch]$Docker,
    [switch]$MySQL,
    [switch]$Redis,
    [switch]$ProtocolBuffers,
    [switch]$All
)

$GoVersion = "1.21.14"
$NodeVersion = "18.20.5"
$DockerVersion = "24.0.9"
$ProtocolBuffersVersion = "25.1"

$GoBaseUrl = "https://go.dev/dl"
$NodeBaseUrl = "https://nodejs.org/dist/v$NodeVersion"
$ProtocolBuffersBaseUrl = "https://github.com/protocolbuffers/protobuf/releases/download/v$ProtocolBuffersVersion"
$DockerBaseUrl = "https://download.docker.com/linux/centos/7/x86_64/stable/Packages"

Write-Host "PowerShell Version: $PSVersionTable.PSVersion.Major" -ForegroundColor Cyan

function Write-Log {
    param([string]$Message, [string]$Type = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = "White"
    if ($Type -eq "INFO") { $color = "Green" }
    if ($Type -eq "WARN") { $color = "Yellow" }
    if ($Type -eq "ERROR") { $color = "Red" }
    if ($Type -eq "STEP") { $color = "Cyan" }
    if ($Type -eq "SUCCESS") { $color = "Green" }
    Write-Host "[$timestamp] [$Type] $Message" -ForegroundColor $color
}

function New-OutputDirectory {
    param([string]$Dir)
    if (-not (Test-Path $Dir)) {
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        Write-Log "Created: $Dir"
    }
}

function Invoke-DownloadFile {
    param([string]$Url, [string]$OutputPath, [string]$Description)
    
    if (Test-Path $OutputPath) {
        $fileSize = (Get-Item $OutputPath).Length
        if ($fileSize -gt 0) {
            Write-Log "$Description exists, skip" -Type "WARN"
            return $true
        }
    }
    
    Write-Log "Downloading $Description..."
    Write-Log "URL: $Url" -Type "INFO"
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $OutputPath)
        $webClient.Dispose()
    }
    catch {
        Write-Log "Download failed: $($_.Exception.Message)" -Type "ERROR"
        return $false
    }
    
    if (Test-Path $OutputPath) {
        $downloadedSize = (Get-Item $OutputPath).Length
        if ($downloadedSize -gt 0) {
            Write-Log "$Description downloaded ($downloadedSize bytes)" -Type "SUCCESS"
            return $true
        }
    }
    
    Write-Log "$Description download failed: empty file" -Type "ERROR"
    return $false
}

function Get-Go {
    Write-Log "Downloading Go $GoVersion..." -Type "STEP"
    $fileName = "go$GoVersion.linux-amd64.tar.gz"
    $outputPath = Join-Path $OutputDir $fileName
    $url = "$GoBaseUrl/$fileName"
    return (Invoke-DownloadFile -Url $url -OutputPath $outputPath -Description "Go $GoVersion")
}

function Get-Node {
    Write-Log "Downloading Node.js $NodeVersion..." -Type "STEP"
    $fileName = "node-v$NodeVersion-linux-x64.tar.xz"
    $outputPath = Join-Path $OutputDir $fileName
    $url = "$NodeBaseUrl/$fileName"
    return (Invoke-DownloadFile -Url $url -OutputPath $outputPath -Description "Node.js $NodeVersion")
}

function Get-ProtocolBuffers {
    Write-Log "Downloading Protocol Buffers $ProtocolBuffersVersion..." -Type "STEP"
    $fileName = "protoc-$ProtocolBuffersVersion-linux-x86_64.zip"
    $outputPath = Join-Path $OutputDir $fileName
    $url = "$ProtocolBuffersBaseUrl/$fileName"
    return (Invoke-DownloadFile -Url $url -OutputPath $outputPath -Description "Protocol Buffers $ProtocolBuffersVersion")
}

function Get-pnpm {
    Write-Log "Downloading pnpm..." -Type "STEP"
    $outputPath = Join-Path $OutputDir "pnpm"
    $url = "https://github.com/pnpm/pnpm/releases/download/v8.15.0/pnpm-linux-x64"
    if (Test-Path $outputPath) {
        $fileSize = (Get-Item $outputPath).Length
        if ($fileSize -gt 0) {
            Write-Log "pnpm exists, skip" -Type "WARN"
            return $true
        }
    }
    return (Invoke-DownloadFile -Url $url -OutputPath $outputPath -Description "pnpm")
}

function Get-DockerRPMS {
    Write-Log "Downloading Docker RPM packages..." -Type "STEP"
    $dockerDir = Join-Path $OutputDir "docker"
    New-OutputDirectory -Dir $dockerDir
    
    $dockerPackages = @(
        "containerd.io-$DockerVersion-3.el7.x86_64.rpm",
        "docker-ce-$DockerVersion-3.el7.x86_64.rpm",
        "docker-ce-cli-$DockerVersion-3.el7.x86_64.rpm",
        "docker-buildx-plugin-0.12.1-1.el7.x86_64.rpm",
        "docker-compose-plugin-2.24.5-1.el7.x86_64.rpm"
    )
    
    $allSuccess = $true
    $count = 0
    
    foreach ($pkg in $dockerPackages) {
        $count++
        $outputPath = Join-Path $dockerDir $pkg
        $url = "$DockerBaseUrl/$pkg"
        Write-Log "Download [$count/$($dockerPackages.Count)]: $pkg" -Type "INFO"
        if (-not (Invoke-DownloadFile -Url $url -OutputPath $outputPath -Description $pkg)) {
            $allSuccess = $false
            Write-Log "Failed: $pkg" -Type "ERROR"
        }
    }
    
    return $allSuccess
}

# Main
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " LumenIM Offline Package Downloader" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

New-OutputDirectory -Dir $OutputDir

Write-Log "Output: $OutputDir"
Write-Log "Target: CentOS 7"
Write-Log "Go: $GoVersion"
Write-Log "Node.js: $NodeVersion"
Write-Log "Docker: $DockerVersion"
Write-Host ""

$downloadGo = $Go.IsPresent -or $All.IsPresent
$downloadNode = $Node.IsPresent -or $All.IsPresent
$downloadDocker = $Docker.IsPresent -or $All.IsPresent
$downloadMySQL = $MySQL.IsPresent -or $All.IsPresent
$downloadRedis = $Redis.IsPresent -or $All.IsPresent
$downloadProtobuf = $ProtocolBuffers.IsPresent -or $All.IsPresent

if (-not $Go.IsPresent -and -not $Node.IsPresent -and -not $Docker.IsPresent -and -not $MySQL.IsPresent -and -not $Redis.IsPresent -and -not $ProtocolBuffers.IsPresent -and -not $All.IsPresent) {
    $downloadGo = $true
    $downloadNode = $true
    $downloadDocker = $true
    $downloadMySQL = $true
    $downloadRedis = $true
    $downloadProtobuf = $true
}

Write-Host "Starting download..." -ForegroundColor Yellow
Write-Host ""

if ($downloadGo) { Get-Go }
if ($downloadNode) { Get-Node }
if ($downloadNode) { Get-pnpm }
if ($downloadProtobuf) { Get-ProtocolBuffers }
if ($downloadDocker) { Get-DockerRPMS }

Write-Host ""
Write-Log "Download complete!" -Type "SUCCESS"
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Downloaded packages:" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$totalSize = 0
Get-ChildItem -Path $OutputDir -Recurse -File | ForEach-Object {
    $size = $_.Length
    $totalSize += $size
    $sizeStr = if ($size -gt 1MB) { "{0:N2} MB" -f ($size/1MB) } elseif ($size -gt 1KB) { "{0:N2} KB" -f ($size/1KB) } else { "$size bytes" }
    Write-Host "  $($_.Name) ($sizeStr)"
}

$totalStr = "{0:N2} MB" -f ($totalSize/1MB)
Write-Host ""
Write-Host "Total: $totalStr" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Copy $OutputDir to USB" -ForegroundColor White
Write-Host "  2. Mount to CentOS 7 server" -ForegroundColor White
Write-Host "  3. Run offline install" -ForegroundColor White
Write-Host ""
Write-Host "Install command:" -ForegroundColor Yellow
Write-Host "  sudo ./install-offline.sh --all --dir=/mnt/packages" -ForegroundColor Gray
Write-Host ""