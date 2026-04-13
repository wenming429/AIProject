#===============================================
# LumenIM Release Package Script
#===============================================

$projectRoot = "d:\学习资料\AI_Projects\LumenIM"
$outDir = "D:\temp\lumenim-packages"

Write-Host "========================================"
Write-Host "  LumenIM release package script"
Write-Host "========================================"

# Create output directory
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

#===============================================
# Backend package
#===============================================
Write-Host ""
Write-Host "[INFO] Packaging backend..."

$backendTemp = "D:\temp\backend-release"
New-Item -ItemType Directory -Force -Path $backendTemp | Out-Null

# Copy backend files
Copy-Item "$projectRoot\backend\config.yaml" $backendTemp -Force
Copy-Item "$projectRoot\backend\docker-compose.yaml" $backendTemp -Force
Copy-Item "$projectRoot\backend\lumenim.exe" $backendTemp -Force
Copy-Item "$projectRoot\backend\sql" $backendTemp -Recurse -Force
Copy-Item "$projectRoot\backend\runtime" $backendTemp -Recurse -Force
Copy-Item "$projectRoot\backend\uploads" $backendTemp -Recurse -Force
Copy-Item "$projectRoot\backend\Makefile" $backendTemp -Force
Copy-Item "$projectRoot\backend\Dockerfile" $backendTemp -Force

Write-Host "[OK] config.yaml"
Write-Host "[OK] docker-compose.yaml"
Write-Host "[OK] lumenim.exe"
Write-Host "[OK] sql/"
Write-Host "[OK] runtime/"
Write-Host "[OK] uploads/"
Write-Host "[OK] Makefile"
Write-Host "[OK] Dockerfile"

# Create zip package
$backendZip = "$outDir\backend.zip"
Compress-Archive -Path "$backendTemp\*" -DestinationPath $backendZip -Force
$size = [math]::Round((Get-Item $backendZip).Length/1MB, 2)
Write-Host "[SUCCESS] Backend package: $backendZip ($size MB)"

#===============================================
# Frontend package
#===============================================
Write-Host ""
Write-Host "[INFO] Packaging frontend..."

$frontTemp = "D:\temp\front-release"
New-Item -ItemType Directory -Force -Path $frontTemp | Out-Null

# Copy frontend files
Copy-Item "$projectRoot\front\dist" $frontTemp -Recurse -Force
Copy-Item "$projectRoot\front\index.html" $frontTemp -Force
Copy-Item "$projectRoot\front\vite.config.ts" $frontTemp -Force

Write-Host "[OK] dist/"
Write-Host "[OK] index.html"
Write-Host "[OK] vite.config.ts"

# Create zip package
$frontZip = "$outDir\front.zip"
Compress-Archive -Path "$frontTemp\*" -DestinationPath $frontZip -Force
$size = [math]::Round((Get-Item $frontZip).Length/1MB, 2)
Write-Host "[SUCCESS] Frontend package: $frontZip ($size MB)"

# Cleanup
Remove-Item $backendTemp -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $frontTemp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "========================================"
Write-Host "[SUCCESS] Done!"
Write-Host ""
Write-Host "Output: $outDir"
Get-ChildItem $outDir | ForEach-Object {
    $s = [math]::Round($_.Length/1MB, 2)
    Write-Host "  $($_.Name) - $s MB"
}
