# Wizzlethorpe Labs Foundry Module Release Script (PowerShell)
# Creates a GitHub release and publishes to FoundryVTT package registry

param(
    [string]$Version
)

$ErrorActionPreference = "Stop"

# Get script directory and set as working directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Load environment variables from .env if it exists
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), "Process")
        }
    }
}

# Read module.json
$moduleJson = Get-Content "module.json" -Raw | ConvertFrom-Json
$currentVersion = $moduleJson.version
$moduleId = $moduleJson.id

Write-Host "Wizzlethorpe Labs Foundry Module Release Script" -ForegroundColor Green
Write-Host "========================================"
Write-Host "Current version: $currentVersion"
Write-Host ""

# Check for required tools
$missingTools = @()
if (-not (Get-Command "gh" -ErrorAction SilentlyContinue)) { $missingTools += "GitHub CLI (gh)" }

if ($missingTools.Count -gt 0) {
    Write-Host "Error: Missing required tools: $($missingTools -join ', ')" -ForegroundColor Red
    exit 1
}

# Check if gh is authenticated
try {
    gh auth status 2>&1 | Out-Null
} catch {
    Write-Host "Error: GitHub CLI not authenticated. Run 'gh auth login' first." -ForegroundColor Red
    exit 1
}

# Get version
if ($Version) {
    $newVersion = $Version
} else {
    $input = Read-Host "Enter new version (or press Enter to keep $currentVersion)"
    $newVersion = if ($input) { $input } else { $currentVersion }
}

# Validate semver format
if ($newVersion -notmatch '^\d+\.\d+\.\d+$') {
    Write-Host "Error: Version must be in semver format (e.g., 2.3.1)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Release version: $newVersion"
Write-Host ""

# Update module.json version if changed
if ($newVersion -ne $currentVersion) {
    Write-Host "Updating module.json version to $newVersion..." -ForegroundColor Yellow
    $moduleJson.version = $newVersion
}

# Update download URL to use specific version tag
Write-Host "Updating download URL for version $newVersion..." -ForegroundColor Yellow
$moduleJson.download = "https://github.com/wizzlethorpe/wizzlethorpe-foundry/releases/download/v$newVersion/module.zip"
$moduleJson | ConvertTo-Json -Depth 10 | Set-Content "module.json" -Encoding UTF8

# Create build directory
$buildDir = Join-Path $env:TEMP "wizzlethorpe-build-$(Get-Random)"
$moduleDir = Join-Path $buildDir $moduleId
New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null

Write-Host "Building release package..." -ForegroundColor Yellow

# Copy module files
Copy-Item "module.json" -Destination $moduleDir
Copy-Item "scripts" -Destination $moduleDir -Recurse
Copy-Item "styles" -Destination $moduleDir -Recurse
Copy-Item "templates" -Destination $moduleDir -Recurse
Copy-Item "lang" -Destination $moduleDir -Recurse
Copy-Item "images" -Destination $moduleDir -Recurse

# Copy optional files if they exist
if (Test-Path "LICENSE") { Copy-Item "LICENSE" -Destination $moduleDir }
if (Test-Path "README.md") { Copy-Item "README.md" -Destination $moduleDir }

# Create zip file
$zipPath = Join-Path $buildDir "module.zip"
Compress-Archive -Path $moduleDir -DestinationPath $zipPath -Force

# Copy zip to script directory
Copy-Item $zipPath -Destination ".\module.zip" -Force

Write-Host "Created module.zip" -ForegroundColor Green

# Create GitHub release
$tag = "v$newVersion"
$releaseNotes = @"
## Wizzlethorpe Labs v$newVersion

### Changes
- See commit history for details

### Installation
- **Manifest URL:** ``https://github.com/wizzlethorpe/wizzlethorpe-foundry/releases/latest/download/module.json``
- **Direct Download:** ``https://github.com/wizzlethorpe/wizzlethorpe-foundry/releases/download/$tag/module.zip``

### Compatibility
- Foundry VTT v13+
"@

Write-Host ""
Write-Host "Creating GitHub release $tag..." -ForegroundColor Yellow

# Check if release already exists
$ErrorActionPreference = "Continue"
gh release view $tag 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Release $tag already exists. Deleting and recreating..." -ForegroundColor Yellow
    gh release delete $tag --yes
    git push origin --delete $tag 2>&1 | Out-Null
}
$ErrorActionPreference = "Stop"

# Create the release with assets
gh release create $tag --title "Wizzlethorpe Labs $newVersion" --notes $releaseNotes module.zip module.json

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to create GitHub release" -ForegroundColor Red
    exit 1
}

Write-Host "GitHub release created successfully!" -ForegroundColor Green
Write-Host ""

# Publish to FoundryVTT Package Registry
$foundryToken = $env:FOUNDRY_RELEASE_TOKEN
if (-not $foundryToken) { $foundryToken = $env:FOUNDRY_API_TOKEN }

if (-not $foundryToken) {
    Write-Host "Skipping FoundryVTT publish (no FOUNDRY_RELEASE_TOKEN in .env)" -ForegroundColor Yellow
    Write-Host "To enable auto-publish, add your token to .env:"
    Write-Host "  FOUNDRY_RELEASE_TOKEN=fvttp_..."
    Write-Host "Get your token at: https://foundryvtt.com/packages/wizzlethorpe-labs/edit"
} else {
    Write-Host "Publishing to FoundryVTT Package Registry..." -ForegroundColor Yellow

    $manifestUrl = "https://github.com/wizzlethorpe/wizzlethorpe-foundry/releases/download/$tag/module.json"

    $body = @{
        id = $moduleId
        "dry-run" = $false
        release = @{
            version = $newVersion
            manifest = $manifestUrl
            notes = "https://github.com/wizzlethorpe/wizzlethorpe-foundry/releases/tag/$tag"
            compatibility = @{
                minimum = "13"
                verified = "13"
            }
        }
    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-RestMethod -Uri "https://foundryvtt.com/_api/packages/release_version/" `
            -Method Post `
            -ContentType "application/json" `
            -Headers @{ Authorization = $foundryToken } `
            -Body $body

        if ($response.status -eq "success") {
            Write-Host "Successfully published to FoundryVTT Package Registry!" -ForegroundColor Green
        } else {
            Write-Host "FoundryVTT publish failed:" -ForegroundColor Red
            $response | ConvertTo-Json
        }
    } catch {
        Write-Host "FoundryVTT publish error:" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
}

# Cleanup
Remove-Item -Path $buildDir -Recurse -Force -ErrorAction SilentlyContinue

# Reset download URL back to latest for development
$moduleJson = Get-Content "module.json" -Raw | ConvertFrom-Json
$moduleJson.download = "https://github.com/wizzlethorpe/wizzlethorpe-foundry/releases/latest/download/module.zip"
$moduleJson | ConvertTo-Json -Depth 10 | Set-Content "module.json" -Encoding UTF8

Write-Host ""
Write-Host "Release complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Release URL: https://github.com/wizzlethorpe/wizzlethorpe-foundry/releases/tag/$tag"
Write-Host "Manifest URL: https://github.com/wizzlethorpe/wizzlethorpe-foundry/releases/download/$tag/module.json"
