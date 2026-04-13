# LumenIM Environment Verification Script v1.0.0
param()
$ErrorCount=0; $WarningCount=0; $SuccessCount=0

function Check($Name,$Cmd,$Pattern,$Required) {
    Write-Host ""
    Write-Host "Checking: $Name" -ForegroundColor Cyan
    try {
        $output = Invoke-Expression $Cmd 2>&1 | Out-String
        if ($output -match $Pattern) {
            Write-Host "  [OK] $output" -ForegroundColor Green
            $script:SuccessCount++
        } elseif ($Required) {
            Write-Host "  [WARNING] Version may not match" -ForegroundColor Yellow
            Write-Host "  Output: $output" -ForegroundColor Yellow
            $script:WarningCount++
        } else {
            Write-Host "  [SKIP]" -ForegroundColor Gray
        }
    } catch {
        if ($Required) {
            Write-Host "  [FAIL]" -ForegroundColor Red
            $script:ErrorCount++
        } else {
            Write-Host "  [SKIP]" -ForegroundColor Gray
        }
    }
}

function Section($Title) {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Magenta
    Write-Host "  $Title" -ForegroundColor Magenta
    Write-Host "============================================" -ForegroundColor Magenta
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   LumenIM Environment Verification v1.0.0" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

Section "System Info"
Write-Host "Computer: $env:COMPUTERNAME" -ForegroundColor White
Write-Host "User: $env:USERNAME" -ForegroundColor White

Section "Core Dependencies (Required)"
Check "Go" "go version" "go1\.\d+" $true
Check "Node.js" "node --version" "v22\.\d+" $true
Check "npm" "npm --version" "\d+" $true
Check "pnpm" "pnpm --version" "\d+" $true
Check "Git" "git --version" "\d+\.\d+" $true

Section "Database Services"
Check "MySQL" "mysql --version" "\d+\.\d+" $true
Check "Redis CLI" "redis-cli --version" "\d+\.\d+" $true

Section "Proto Tools"
Check "protoc" "protoc --version" "\d+\.\d+" $false
Check "protoc-gen-go" "protoc-gen-go --version" "v\d+" $false

Section "Disk Space"
$drive = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null } | Select-Object -First 1
$freeGB = [math]::Round($drive.Free / 1GB, 2)
$color = if ($freeGB -gt 10) { "Green" } else { "Yellow" }
Write-Host "System Drive Free Space: $freeGB GB" -ForegroundColor $color

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   Summary" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Success: $SuccessCount" -ForegroundColor Green
Write-Host "  Warning: $WarningCount" -ForegroundColor Yellow
Write-Host "  Failed: $ErrorCount" -ForegroundColor $(if ($ErrorCount -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($ErrorCount -eq 0 -and $WarningCount -eq 0) {
    Write-Host "  All checks passed! Environment is ready." -ForegroundColor Green
} elseif ($ErrorCount -eq 0) {
    Write-Host "  Checks passed with $WarningCount warning(s)." -ForegroundColor Yellow
} else {
    Write-Host "  $ErrorCount required check(s) failed!" -ForegroundColor Red
}
