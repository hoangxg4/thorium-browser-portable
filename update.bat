@echo off
setlocal
echo Thorium Portable Updater v1.0
echo =======================================
echo.
set "APP_DIR=%~dp0"
set "APP_DIR=%APP_DIR:~0,-1%"
set "PS1=%TEMP%\thorium_update.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$env:APP_DIR='%APP_DIR%'; (Get-Content '%~f0' | Select-Object -Skip 12) | Out-File -Encoding utf8 '%PS1%'; & '%PS1%'"
del "%PS1%" 2>nul
exit /b

$appDir = $env:APP_DIR
$versionPath = Join-Path $appDir "version.txt"
$thoriumPath = Join-Path $appDir "BIN\thorium.exe"
$apiUrl = "https://api.github.com/repos/Alex313031/Thorium-Win/releases"
$tempDir = Join-Path $env:TEMP "ThoriumUpdate"

try {
    $currentVersion = if (Test-Path $versionPath) { Get-Content $versionPath -Raw } else { "Not installed" }

    $allReleases = Invoke-RestMethod -Uri $apiUrl
    $latestRelease = $allReleases | Where-Object { -not $_.prerelease } | Select-Object -First 1
    $latestTag = $latestRelease.tag_name
    $latestVersion = $latestTag -replace '^M', ''
    $downloadUrl = ($latestRelease.assets | Where-Object { $_.name -like "*AVX2*.zip*" }).browser_download_url

    if (-not $downloadUrl) {
        Write-Host "Error: Could not find AVX2 x64 zip asset" -ForegroundColor Red
        exit 1
    }

    Write-Host "Current version: $currentVersion" -ForegroundColor Yellow
    Write-Host "Latest version:  $latestVersion" -ForegroundColor Yellow
    Write-Host

    if ($currentVersion -eq $latestVersion) {
        Write-Host "Already up to date!" -ForegroundColor Green
        exit 0
    }

    $confirm = Read-Host "Do you want to update? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') { exit }

    Write-Host "Stopping processes..."
    Stop-Process -Name thorium -Force -ErrorAction SilentlyContinue
    Start-Sleep 2

    if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $zipFile = Join-Path $tempDir "thorium.zip"

    Write-Host "Downloading latest version..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, $zipFile)

    Write-Host "Extracting..."
    Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force

    $extractedDir = Get-ChildItem $tempDir -Directory | Select-Object -First 1
    if (-not $extractedDir) {
        Write-Host "Error: Could not find extracted Thorium folder" -ForegroundColor Red
        exit 1
    }

    $protectedFiles = @("chrome++.ini", "default-apps-multi-profile.bat", "update.bat")

    Write-Host "Updating files..."
    Get-ChildItem $extractedDir.FullName -Recurse | ForEach-Object {
        $relativePath = $_.FullName.Substring($extractedDir.FullName.Length + 1)
        $destPath = Join-Path $appDir $relativePath
        if ($_.PSIsContainer) {
            if (-not (Test-Path $destPath)) { New-Item -ItemType Directory -Path $destPath -Force | Out-Null }
        } else {
            if ($_.Name -in $protectedFiles) {
                Write-Host "  Skipping protected: $($_.Name)"
            } else {
                $destFolder = Split-Path $destPath -Parent
                if (-not (Test-Path $destFolder)) { New-Item -ItemType Directory -Path $destFolder -Force | Out-Null }
                Copy-Item $_.FullName -Destination $destPath -Force
            }
        }
    }

    # Write new version
    Set-Content -Path $versionPath -Value $latestVersion

    Remove-Item $tempDir -Recurse -Force

    Write-Host "Update completed! Version: $latestVersion" -ForegroundColor Green

} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
}

Read-Host "Press Enter to exit"
