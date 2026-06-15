#Requires -Version 7.0
<#
.SYNOPSIS
    Build / test / publish orchestrator for the WindowsCloudPC module.

.PARAMETER Task
    Lint, Test, Build, Publish, or All (default = Lint + Test + Build).

.PARAMETER ApiKey
    PSGallery NuGet API key. Defaults to $env:PSGALLERY_API_KEY. Required for Publish.

.PARAMETER OutputPath
    Where to stage the built module. Defaults to .\Output\WindowsCloudPC.

.EXAMPLE
    ./build.ps1                     # lint + test + build
    ./build.ps1 -Task Lint
    ./build.ps1 -Task Test
    ./build.ps1 -Task Publish       # CI release pipeline only
#>
[CmdletBinding()]
param(
    [ValidateSet('Lint','Test','Build','Publish','All')]
    [string]$Task = 'All',
    [string]$ApiKey = $env:PSGALLERY_API_KEY,
    [string]$OutputPath = (Join-Path $PSScriptRoot 'Output\WindowsCloudPC')
)

$ErrorActionPreference = 'Stop'
$ModuleRoot = $PSScriptRoot

# ----- helpers ------------------------------------------------------------

function Install-RequiredModule {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$MinimumVersion
    )
    $existing = Get-Module -ListAvailable -Name $Name
    if ($MinimumVersion) {
        $existing = $existing | Where-Object { $_.Version -ge [version]$MinimumVersion }
    }
    if (-not $existing) {
        Write-Host "  installing $Name..." -ForegroundColor DarkGray
        $installParams = @{
            Name               = $Name
            Scope              = 'CurrentUser'
            Force              = $true
            SkipPublisherCheck = $true
            AllowClobber       = $true
        }
        if ($MinimumVersion) { $installParams.MinimumVersion = $MinimumVersion }
        Install-Module @installParams
    }
    $importParams = @{ Name = $Name; ErrorAction = 'Stop' }
    if ($MinimumVersion) { $importParams.MinimumVersion = $MinimumVersion }
    Import-Module @importParams
}

function Initialize-BuildEnvironment {
    Write-Host "==> Preparing build environment" -ForegroundColor Cyan
    Install-RequiredModule -Name Pester                          -MinimumVersion 5.5.0
    Install-RequiredModule -Name PSScriptAnalyzer                -MinimumVersion 1.21.0
    Install-RequiredModule -Name Microsoft.Graph.Authentication  -MinimumVersion 2.0.0
}

function Invoke-LintTask {
    Write-Host "==> Lint (PSScriptAnalyzer / PSGallery ruleset)" -ForegroundColor Cyan
    # Lint module code only. build.ps1 and Tests/ use patterns (Write-Host, mock vars) that
    # PSScriptAnalyzer flags as false positives.
    $paths = @(
        Join-Path $ModuleRoot 'WindowsCloudPC.psd1'
        Join-Path $ModuleRoot 'WindowsCloudPC.psm1'
        Join-Path $ModuleRoot 'Public'
        Join-Path $ModuleRoot 'Private'
    )
    $issues = foreach ($p in $paths) {
        if (Test-Path $p) { Invoke-ScriptAnalyzer -Path $p -Recurse -Settings PSGallery }
    }
    if ($issues) {
        $issues | Format-Table -AutoSize | Out-Host
        $blocking = $issues | Where-Object Severity -in 'Error','Warning'
        if ($blocking) { throw "$($blocking.Count) blocking lint issue(s)." }
    }
    else {
        Write-Host "  OK" -ForegroundColor Green
    }
}

function Invoke-TestTask {
    Write-Host "==> Test (Pester)" -ForegroundColor Cyan
    $outputDir = Join-Path $ModuleRoot 'Output'
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

    $config = New-PesterConfiguration
    $config.Run.Path                  = Join-Path $ModuleRoot 'Tests'
    $config.Run.Exit                  = $false
    $config.Run.Throw                 = $true
    $config.Output.Verbosity          = 'Detailed'
    $config.TestResult.Enabled        = $true
    $config.TestResult.OutputPath     = Join-Path $outputDir 'TestResults.xml'
    $config.TestResult.OutputFormat   = 'NUnitXml'
    $config.CodeCoverage.Enabled      = $true
    $config.CodeCoverage.Path         = @(
        Join-Path $ModuleRoot 'Public\*.ps1'
        Join-Path $ModuleRoot 'Private\*.ps1'
    )
    $config.CodeCoverage.OutputPath   = Join-Path $outputDir 'Coverage.xml'
    $config.CodeCoverage.OutputFormat = 'JaCoCo'

    Invoke-Pester -Configuration $config
}

function Invoke-BuildTask {
    Write-Host "==> Build (stage module to $OutputPath)" -ForegroundColor Cyan
    if (Test-Path $OutputPath) { Remove-Item $OutputPath -Recurse -Force }
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

    $items = @('WindowsCloudPC.psd1','WindowsCloudPC.psm1','Public','Private','README.md','CHANGELOG.md','LICENSE')
    foreach ($item in $items) {
        $src = Join-Path $ModuleRoot $item
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination $OutputPath -Recurse -Force
        }
    }

    $stagedManifest = Join-Path $OutputPath 'WindowsCloudPC.psd1'
    $info = Test-ModuleManifest -Path $stagedManifest
    Write-Host ("  staged {0} v{1}" -f $info.Name, $info.Version) -ForegroundColor Green
}

function Invoke-PublishTask {
    Write-Host "==> Publish (PSGallery)" -ForegroundColor Cyan
    if (-not $ApiKey) { throw "ApiKey / `$env:PSGALLERY_API_KEY is required for Publish." }
    if (-not (Test-Path $OutputPath)) { throw "No staged build at $OutputPath. Run -Task Build first." }
    Publish-Module -Path $OutputPath -NuGetApiKey $ApiKey -Verbose
    Write-Host "  published" -ForegroundColor Green
}

# ----- run ----------------------------------------------------------------

Initialize-BuildEnvironment

switch ($Task) {
    'Lint'    { Invoke-LintTask }
    'Test'    { Invoke-TestTask }
    'Build'   { Invoke-LintTask; Invoke-TestTask; Invoke-BuildTask }
    'Publish' { Invoke-LintTask; Invoke-TestTask; Invoke-BuildTask; Invoke-PublishTask }
    'All'     { Invoke-LintTask; Invoke-TestTask; Invoke-BuildTask }
}
