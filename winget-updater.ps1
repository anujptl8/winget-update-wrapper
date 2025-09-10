# Self-elevate if not running as admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    $scriptPath = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy Bypass", "-File `"$scriptPath`"" -Verb RunAs
    exit
}


# Winget-updater.ps1
$ErrorActionPreference = "Stop"

# Get upgradeable packages
$rawOutput = winget upgrade --source winget | Out-String
$lines = $rawOutput -split "`r?`n" | Where-Object { $_ -match '\S' }

# Remove progress bar lines
$cleanLines = $lines | Where-Object {
    ($_ -notmatch '[█▒]') -and ($_ -notmatch '\d+(\.\d+)?\s*(KB|MB)\s*/\s*\d+(\.\d+)?\s*(KB|MB)')
}

# Extract package lines and skip the header row
$packageLines = $cleanLines | Where-Object {
    ($_ -match '^\s*\S+\s+\S+\s+\S+\s+\S+') -and
    ($_ -notmatch '^\s*Name\s+Id\s+Version\s+Available')
}

if ($packageLines.Count -eq 0) {
    Write-Host "No upgrades available." -ForegroundColor Yellow
    exit
}

# Display list with serial numbers
Write-Host "`nUpgradeable packages:`n" -ForegroundColor Cyan
$indexedPackages = @()
$index = 1
foreach ($line in $packageLines) {
    Write-Host "${index}: $line"
    $indexedPackages += $line
    $index++
}

# Prompt for selection
Write-Host "`nEnter the serial number of the package to upgrade (q to quit):" -NoNewline
$choice = Read-Host

if ($choice -eq 'q') {
    Write-Host "Exiting..." -ForegroundColor Gray
    exit
}

if ($choice -notmatch '^\d+$' -or [int]$choice -lt 1 -or [int]$choice -gt $indexedPackages.Count) {
    Write-Host "Invalid input. Please enter a valid number." -ForegroundColor Red
    exit
}

# Extract package ID from selected line
$selectedLine = $indexedPackages[[int]$choice - 1]
$columns = $selectedLine -split '\s{2,}'
$packageId = $columns[1]  # Winget ID is usually the second column

Write-Host "`nUpgrading package: $packageId" -ForegroundColor Green
winget upgrade --id $packageId --silent
