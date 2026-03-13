# BaoBun Installation Script for Windows
# Usage: irm https://raw.githubusercontent.com/FullyAutonomous/BaoBun/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

$BAOBUN_REPO = "FullyAutonomous/BaoBun"
$REPO_URL = "https://github.com/$BAOBUN_REPO"
$INSTALL_DIR = $env:INSTALL_DIR
if (-not $INSTALL_DIR) {
    $INSTALL_DIR = "$env:USERPROFILE\.baobun\bin"
}

# Helper functions
function Write-Info($message) {
    Write-Host "ℹ $message" -ForegroundColor Blue
}

function Write-Success($message) {
    Write-Host "✓ $message" -ForegroundColor Green
}

function Write-Warn($message) {
    Write-Host "⚠ $message" -ForegroundColor Yellow
}

function Write-Error($message) {
    Write-Host "✗ $message" -ForegroundColor Red
}

# Detect architecture
function Get-Architecture {
    $arch = $env:PROCESSOR_ARCHITECTURE
    switch ($arch) {
        "AMD64" { return "x64" }
        "ARM64" { return "arm64" }
        default { return "unknown" }
    }
}

# Get latest release version
function Get-LatestVersion {
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$BAOBUN_REPO/releases/latest" -UseBasicParsing
        return $response.tag_name
    }
    catch {
        return $null
    }
}

# Download and install BaoBun
function Install-BaoBun {
    param(
        [string]$arch,
        [string]$version
    )
    
    Write-Info "Installing BaoBun $version for windows-$arch..."
    
    # Create install directory
    New-Item -ItemType Directory -Force -Path $INSTALL_DIR | Out-Null
    
    # Determine binary URL
    $binaryName = "baobun-windows-$arch.zip"
    $downloadUrl = "$REPO_URL/releases/download/$version/$binaryName"
    $tempDir = [System.IO.Path]::GetTempPath() + [System.Guid]::NewGuid().ToString()
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    $zipFile = "$tempDir\baobun.zip"
    
    Write-Info "Downloading from $downloadUrl..."
    
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile -UseBasicParsing
    }
    catch {
        Write-Error "Failed to download BaoBun"
        Write-Error "URL: $downloadUrl"
        Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
        exit 1
    }
    
    Write-Info "Extracting..."
    Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force
    
    # Find the baobun binary (or bun as fallback)
    $extractedBinary = Get-ChildItem -Path $tempDir -Filter "baobun-*.exe" -Recurse | Select-Object -First 1
    if (-not $extractedBinary) {
        $extractedBinary = Get-ChildItem -Path $tempDir -Filter "bun.exe" -Recurse | Select-Object -First 1
    }
    
    if (-not $extractedBinary) {
        Write-Error "Could not find BaoBun binary in downloaded archive"
        Write-Error "Looking for: baobun-windows-$arch.exe or bun.exe"
        Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
        exit 1
    }
    
    # Move binary to install location
    $targetBinary = "$INSTALL_DIR\bun.exe"
    Move-Item -Path $extractedBinary.FullName -Destination $targetBinary -Force
    
    # Create baobun alias (batch file wrapper)
    $baobunAlias = "$INSTALL_DIR\baobun.bat"
    $batchContent = "@echo off`n`"$INSTALL_DIR\bun.exe`" %*"
    Set-Content -Path $baobunAlias -Value $batchContent -Force
    Write-Success "Created baobun alias"
    
    # Cleanup
    Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
    
    Write-Success "BaoBun installed to $targetBinary"
}

# Add to PATH
function Add-ToPath {
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    
    if ($currentPath -like "*$INSTALL_DIR*") {
        Write-Info "Install directory already in PATH"
        return
    }
    
    Write-Info "Adding $INSTALL_DIR to PATH..."
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$INSTALL_DIR", "User")
    Write-Success "Added to PATH (restart your terminal to use)"
}

# Verify installation
function Verify-Installation {
    $bunPath = "$INSTALL_DIR\bun.exe"
    if (Test-Path $bunPath) {
        Write-Success "BaoBun is ready to use!"
        Write-Host ""
        & $bunPath --version
    }
    else {
        Write-Warn "BaoBun installed but not in current PATH"
        Write-Info "Restart your terminal or run: `$env:Path = [Environment]::GetEnvironmentVariable('Path', 'User')`"
    }
}

# Main installation flow
function Main {
    Write-Host ""
    Write-Host "🥟 BaoBun Installer" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    Write-Host ""
    
    # Detect architecture
    $arch = Get-Architecture
    Write-Info "Detected architecture: $arch"
    
    if ($arch -eq "unknown") {
        Write-Error "Unsupported architecture: $env:PROCESSOR_ARCHITECTURE"
        exit 1
    }
    
    # Check for required tools
    if (-not (Get-Command "curl" -ErrorAction SilentlyContinue) -and 
        -not (Get-Command "Invoke-WebRequest" -ErrorAction SilentlyContinue)) {
        Write-Error "Neither curl nor Invoke-WebRequest is available"
        exit 1
    }
    
    # Get latest version
    Write-Info "Checking for latest release..."
    $version = Get-LatestVersion
    
    if (-not $version) {
        Write-Error "Could not determine latest version"
        exit 1
    }
    
    Write-Info "Latest version: $version"
    
    # Install
    Install-BaoBun -arch $arch -version $version
    
    # Setup PATH
    Add-ToPath
    
    # Verify
    Write-Host ""
    Verify-Installation
    
    Write-Host ""
    Write-Host "📚 Quick Start:" -ForegroundColor Cyan
    Write-Host "   bun run index.ts    # Run TypeScript"
    Write-Host "   bun install         # Install dependencies"
    Write-Host "   bun test            # Run tests"
    Write-Host ""
    Write-Host "🎉 Happy coding with BaoBun!" -ForegroundColor Green
    Write-Host ""
}

# Run main function
Main
