#===============================================
# LumenIM Local Publish Script v2.0
#===============================================
param(
    [switch]$SkipBuild,
    [switch]$BackendOnly,
    [switch]$FrontendOnly,
    [switch]$CheckEnv,
    [string]$OutputDir = "D:\temp\lumenim-release"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot | Split-Path -Parent
$REQUIRED_GO_VERSION = "1.21"
$REQUIRED_NODE_VERSION = "18"
$REQUIRED_PNPM_VERSION = "8"

# Output functions
function Write-Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Success($m) { Write-Host "[SUCCESS] $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err($m) { Write-Host "[ERROR] $m" -ForegroundColor Red }
function Write-Section($m) { Write-Host "`n========== $m ==========" -ForegroundColor Magenta }

# Version comparison
function Get-VerNum([string]$v) {
    try { [version](($v -replace '[^0-9.]', '') -split '-')[0] }
    catch { [version]"0.0.0" }
}

function Test-Ver($installed, $required, $name) {
    $iv = Get-VerNum $installed
    $rv = Get-VerNum $required
    if ($iv -ge $rv) {
        Write-Success "$name $installed (>= $required)"
        return $true
    } else {
        Write-Err "$name $installed (requires >= $required)"
        return $false
    }
}

# Environment checks
function Test-Docker {
    Write-Section "Checking Docker"
    try {
        $v = docker --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success $v
            return $true
        }
    } catch { }
    Write-Err "Docker not installed or not running"
    Write-Info "Install: https://www.docker.com/products/docker-desktop"
    return $false
}

function Test-Go {
    Write-Section "Checking Go"
    try {
        $v = go version 2>&1
        if ($LASTEXITCODE -eq 0) {
            if ($v -match 'go(\d+\.\d+\.?\d*)') {
                return Test-Ver $matches[1] $REQUIRED_GO_VERSION "Go"
            }
            Write-Success $v
            return $true
        }
    } catch { }
    Write-Err "Go not installed"
    Write-Info "Install: choco install golang"
    return $false
}

function Test-Node {
    Write-Section "Checking Node.js"
    try {
        $v = node --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            return Test-Ver ($v -replace 'v', '') $REQUIRED_NODE_VERSION "Node.js"
        }
    } catch { }
    Write-Err "Node.js not installed"
    Write-Info "Install: choco install nodejs"
    return $false
}

function Test-Pnpm {
    Write-Section "Checking pnpm"
    try {
        $v = pnpm --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            return Test-Ver $v $REQUIRED_PNPM_VERSION "pnpm"
        }
    } catch { }
    Write-Err "pnpm not installed"
    Write-Info "Install: npm install -g pnpm"
    return $false
}

function Test-Git {
    Write-Section "Checking Git"
    try {
        $v = git --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success $v
            return $true
        }
    } catch { }
    Write-Err "Git not installed"
    Write-Info "Install: choco install git"
    return $false
}

function Test-Environment {
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "  LumenIM Environment Check" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta

    $results = @{
        Docker = (Test-Docker)
        Go     = (Test-Go)
        Node   = (Test-Node)
        Pnpm   = (Test-Pnpm)
        Git    = (Test-Git)
    }

    Write-Section "Check Results"
    $allPassed = $true

    foreach ($key in $results.Keys) {
        $status = if ($results[$key]) { "[OK]" } else { "[FAIL]" }
        $color = if ($results[$key]) { "Green" } else { "Red" }
        Write-Host "  $key : $status" -ForegroundColor $color
        if (-not $results[$key]) {
            $allPassed = $false
        }
    }

    if ($allPassed) {
        Write-Success "`nAll checks passed!"
    } else {
        Write-Err "`nSome checks failed"
    }
    return $allPassed
}

# Clean build artifacts
function Clear-Build {
    Write-Section "Cleaning old build"
    foreach ($binary in @("lumenim.exe", "lumenim.exe~", "lumenim-backend")) {
        $path = Join-Path $ProjectRoot "backend\$binary"
        if (Test-Path $path) {
            Remove-Item $path -Force
            Write-Info "Removed: $binary"
        }
    }
    Write-Success "Clean complete"
}

# Build backend
function Build-Backend {
    Write-Section "Building Backend"
    $dir = Join-Path $ProjectRoot "backend"
    Push-Location $dir
    try {
        Write-Info "Running: go build -ldflags=`"-s -w`" -o lumenim.exe ./cmd/server"
        go build -ldflags="-s -w" -o lumenim.exe ./cmd/server
        if ($LASTEXITCODE -eq 0 -and (Test-Path "lumenim.exe")) {
            $size = [math]::Round((Get-Item "lumenim.exe").Length / 1MB, 2)
            Write-Success "Backend build success: lumenim.exe ($size MB)"
            return $true
        }
        Write-Err "Backend build failed"
        return $false
    } catch {
        Write-Err "Build error: $_"
        return $false
    } finally {
        Pop-Location
    }
}

# Build frontend
function Build-Frontend {
    Write-Section "Building Frontend"
    $dir = Join-Path $ProjectRoot "front"
    Push-Location $dir
    try {
        if (-not (Test-Path "node_modules")) {
            Write-Info "Installing dependencies..."
            pnpm install
            if ($LASTEXITCODE -ne 0) {
                Write-Err "Dependency install failed"
                return $false
            }
        }
        Write-Info "Running: pnpm run build"
        pnpm run build
        if ($LASTEXITCODE -eq 0 -and (Test-Path "dist")) {
            $count = (Get-ChildItem dist -Recurse -File).Count
            Write-Success "Frontend build success: dist/ ($count files)"
            return $true
        }
        Write-Err "Frontend build failed"
        return $false
    } catch {
        Write-Err "Build error: $_"
        return $false
    } finally {
        Pop-Location
    }
}

# Check config files
function Test-Config {
    Write-Section "Checking config files"
    $backendDir = Join-Path $ProjectRoot "backend"
    $frontDir = Join-Path $ProjectRoot "front"
    $ok = $true

    # Check for config.yaml (primary config file)
    if (Test-Path "$backendDir\config.yaml") {
        Write-Success "config.yaml exists"
    } elseif (Test-Path "$backendDir\.env") {
        Write-Success ".env exists"
    } elseif (Test-Path "$backendDir\.env.example") {
        Write-Success ".env.example exists (copy to .env for local dev)"
    } else {
        Write-Err "No config file found (need config.yaml or .env)"
        $ok = $false
    }

    if (Test-Path "$frontDir\dist") {
        Write-Success "Frontend dist/ exists"
    } else {
        Write-Warn "Frontend dist/ not found"
    }

    return $ok
}

# Create release package
function New-ReleasePackage {
    Write-Section "Creating release package"

    $backendOut = Join-Path $OutputDir "backend"
    $frontOut = Join-Path $OutputDir "frontend"

    New-Item -ItemType Directory -Force -Path $backendOut, $frontOut | Out-Null

    $backendDir = Join-Path $ProjectRoot "backend"
    $frontDir = Join-Path $ProjectRoot "front"

    # Backend files
    $files = @(".env", ".env.example", "config.yaml", "config.example.yaml", "docker-compose.yaml", "lumenim.exe", "lumenim.exe~")
    foreach ($file in $files) {
        $src = Join-Path $backendDir $file
        $dst = Join-Path $backendOut (Split-Path $file -Leaf)
        if (Test-Path $src) {
            Copy-Item $src $dst -Force
        }
    }

    $dirs = @("sql", "runtime", "uploads")
    foreach ($d in $dirs) {
        $src = Join-Path $backendDir $d
        $dst = Join-Path $backendOut $d
        if (Test-Path $src) {
            Copy-Item $src $dst -Recurse -Force
        }
    }

    # Copy api proto files (exclude generated files)
    $apiSrc = Join-Path $backendDir "api"
    $apiDst = Join-Path $backendOut "api"
    if (Test-Path $apiSrc) {
        New-Item -ItemType Directory -Force -Path $apiDst | Out-Null
        Get-ChildItem $apiSrc -Recurse -File | Where-Object {
            $_.Extension -notin @('.pb.go', '.pb.gw.go')
        } | ForEach-Object {
            $relPath = $_.FullName.Substring($apiSrc.Length).TrimStart('\', '/')
            $destPath = Join-Path $apiDst $relPath
            $destDir = Split-Path -Parent $destPath
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item $_.FullName $destPath -Force
        }
    }

    $extraFiles = @("Makefile", "Dockerfile", "README.md")
    foreach ($file in $extraFiles) {
        $src = Join-Path $backendDir $file
        if (Test-Path $src) {
            Copy-Item $src $backendOut -Force
        }
    }

    Write-Success "Backend files copied"

    # Frontend files
    if (Test-Path "$frontDir\dist") {
        Copy-Item "$frontDir\dist" $frontOut -Recurse -Force
        Write-Success "Frontend dist/ copied"
    }

    $frontFiles = @("index.html", "vite.config.ts", "package.json")
    foreach ($file in $frontFiles) {
        $src = Join-Path $frontDir $file
        if (Test-Path $src) {
            Copy-Item $src $frontOut -Force
        }
    }

    if (Test-Path "$frontDir\public") {
        Copy-Item "$frontDir\public" $frontOut -Recurse -Force
    }

    Write-Success "Frontend files copied"

    # Create tarball
    Write-Section "Creating tarball"
    $tarDir = Join-Path $OutputDir "tarballs"
    New-Item -ItemType Directory -Force -Path $tarDir | Out-Null

    if (Get-Command tar -ErrorAction SilentlyContinue) {
        Write-Info "Using tar command..."

        $tmpBackend = Join-Path $tarDir "backend_temp"
        $tmpFrontend = Join-Path $tarDir "front_temp"

        Copy-Item $backendOut $tmpBackend -Recurse -Force
        Copy-Item $frontOut $tmpFrontend -Recurse -Force

        Push-Location $tarDir
        tar -czvf "backend.tar.gz" -C backend_temp .
        tar -czvf "frontend.tar.gz" -C front_temp .
        Pop-Location

        Remove-Item $tmpBackend, $tmpFrontend -Recurse -Force -ErrorAction SilentlyContinue

        $backendPkg = Join-Path $tarDir "backend.tar.gz"
        $frontPkg = Join-Path $tarDir "frontend.tar.gz"

        $s1 = [math]::Round((Get-Item $backendPkg).Length / 1MB, 2)
        $s2 = [math]::Round((Get-Item $frontPkg).Length / 1MB, 2)

        Write-Success "Backend: backend.tar.gz ($s1 MB)"
        Write-Success "Frontend: frontend.tar.gz ($s2 MB)"
    } else {
        Write-Warn "tar not available, using zip format"

        $backendZip = Join-Path $tarDir "backend.zip"
        $frontZip = Join-Path $tarDir "frontend.zip"

        Compress-Archive -Path "$backendOut\*" -DestinationPath $backendZip -Force
        Compress-Archive -Path "$frontOut\*" -DestinationPath $frontZip -Force

        $s1 = [math]::Round((Get-Item $backendZip).Length / 1MB, 2)
        $s2 = [math]::Round((Get-Item $frontZip).Length / 1MB, 2)

        Write-Success "Backend: backend.zip ($s1 MB)"
        Write-Success "Frontend: frontend.zip ($s2 MB)"
    }

    return $true
}

# Generate deploy README
function New-DeployReadme {
    Write-Section "Generating deploy README"

    $readmeContent = @"
# LumenIM Release Package

## Directory Structure
    lumenim-release/
    ├── backend.tar.gz      # Backend package
    ├── frontend.tar.gz     # Frontend package
    ├── tarballs/           # Compressed packages
    ├── backend/            # Backend files
    └── frontend/           # Frontend files

## Deployment Steps
1. Upload to server: `scp backend.tar.gz root@IP:/mnt/packages/`
2. SSH to server and run: `sudo ./software/deploy-packages.sh`
3. Verify: `curl http://localhost:9501`

## Requirements
- Docker 20.10+, Nginx 1.20+, MySQL 8.0, Redis 7.x

## Config Files
Backend .env must contain: DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME, REDIS_HOST, REDIS_PORT
"@

    $readmePath = Join-Path $OutputDir "README.md"
    Set-Content -Path $readmePath -Value $readmeContent -Encoding UTF8
    Write-Success "README.md generated"
}

# Main flow
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  LumenIM Local Publish Script v2.0" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

if (-not (Test-Environment)) {
    exit 1
}

if ($CheckEnv) {
    Write-Success "Environment check complete"
    exit 0
}

if (-not $SkipBuild) {
    if (-not $FrontendOnly) {
        Clear-Build
        if (-not (Test-Config)) {
            Write-Err "Config check failed"
            exit 1
        }
    }

    if (-not $FrontendOnly -and -not $BackendOnly) {
        Build-Backend
    }

    if (-not $BackendOnly -and -not $FrontendOnly) {
        Build-Frontend
    }

    if ($BackendOnly) {
        Build-Backend
    }

    if ($FrontendOnly) {
        Build-Frontend
    }
}

New-ReleasePackage
New-DeployReadme

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Success "Release package ready!"
Write-Host "Output: $OutputDir" -ForegroundColor Cyan
Write-Host "`nNext: Upload tarballs to server and run deploy script" -ForegroundColor Yellow
