# PowerShell script to test with specific Spectre.Console.Cli versions
# Test-WithSpectreVersions.ps1

param(
    [Parameter(Mandatory = $false)]
    [string[]]$SpectreVersions,
    
    [Parameter(Mandatory = $false)]
    [switch]$UseVersionsFromJson
)

# Working directory - adjust if needed
$workingDirectory = ".\src"
Set-Location $workingDirectory
# If no versions specified and -UseVersionsFromJson is set, read from JSON
if ($UseVersionsFromJson -and !$SpectreVersions) {
    $jsonPath = ".\..\.github\package-versions\spectre-console-cli-versions.json"
    
    if (Test-Path $jsonPath) {
        $versionData = Get-Content $jsonPath | ConvertFrom-Json
        $SpectreVersions = $versionData.versions
    }
    else {
        Write-Warning "Version JSON file not found at: $jsonPath"
        Write-Host "Falling back to default versions"
        $SpectreVersions = @('0.46.1-preview.0.19', '0.47.0', '0.48.0', '0.48.1-preview.0.35')
    }
}
elseif (!$SpectreVersions) {
    # Default if no versions specified and not using JSON
    $SpectreVersions = @('0.46.1-preview.0.19', '0.47.0', '0.48.0', '0.48.1-preview.0.35')
}

# Show which versions we'll be testing with
Write-Host "Testing with these Spectre.Console.Cli versions:" -ForegroundColor Cyan
$SpectreVersions | ForEach-Object { Write-Host "- $_" -ForegroundColor Cyan }

# Initial cleanup
Write-Host "`nCleaning solution..." -ForegroundColor Yellow
dotnet clean CiFilter.slnf

# Remove Test-Results.txt
$testResultsFilepath = "$PSScriptRoot\test-results.txt"
Remove-Item -Path $testResultsFilepath -ErrorAction SilentlyContinue

"Test run started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")" | Add-Content -Path $testResultsFilepath
"`nVersions to test:" | Add-Content -Path $testResultsFilepath
$SpectreVersions | ForEach-Object { "    $_" } | Add-Content -Path $testResultsFilepath

"" | Add-Content -Path $testResultsFilepath

# For each version, run the tests
foreach ($version in $SpectreVersions) {
    Write-Host "`n====================================================" -ForegroundColor Green
    Write-Host "Testing with Spectre.Console.Cli version: $version" -ForegroundColor Green
    Write-Host "====================================================" -ForegroundColor Green
    
    # Restore, build, and test
    Write-Host "Restoring packages..." -ForegroundColor Yellow
    dotnet restore CiFilter.slnf /p:SpectreConsoleVersion=$version

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Restore failed for version $version" -ForegroundColor Red
        "[Failed]    [Restore] $version" | Add-Content -Path $testResultsFilepath
    }
    else {
        Write-Host "Building solution..." -ForegroundColor Yellow
        dotnet build CiFilter.slnf --no-restore /p:SpectreConsoleVersion=$version /t:Rebuild

        if ($LASTEXITCODE -ne 0) {
            Write-Host "Build failed for version $version" -ForegroundColor Red
            "[Failed]    [Build]   $version" | Add-Content -Path $testResultsFilepath
        }
        else {
            Write-Host "Running tests..." -ForegroundColor Yellow
            dotnet test CiFilter.slnf --no-build /p:SpectreConsoleVersion=$version
    
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Tests failed for version $version" -ForegroundColor Red
                "[Failed]    [Tests]   $version" | Add-Content -Path $testResultsFilepath
            }
            else {
                Write-Host "Tests passed for version $version" -ForegroundColor Green
                "[Succeeded] [Tests]   $version" | Add-Content -Path $testResultsFilepath
            }
        }
    }

    Start-Sleep 0.5
}

Set-Location $PSScriptRoot

Write-Host "`nTesting completed for all versions." -ForegroundColor Cyan

Write-Host "`nTest results can be found in: " -NoNewline
Write-Host ".\$([System.IO.Path]::GetFileName($testResultsFilepath))`n" -ForegroundColor Cyan
