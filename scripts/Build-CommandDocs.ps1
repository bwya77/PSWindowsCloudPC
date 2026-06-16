#Requires -Version 7.0
<#
.SYNOPSIS
    Generates Docusaurus markdown command reference pages for WindowsCloudPC.

.DESCRIPTION
    Reads public function comment-based help, module metadata, and PowerShell
    Gallery metadata. Outputs docs/commands/*.md and src/data/stats.json for
    the Docusaurus site.
#>
[CmdletBinding()]
param(
    [string]$DocsPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'docs\commands'),
    [string]$StatsPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'src\data\stats.json')
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent
$ManifestPath = Join-Path $RepoRoot 'WindowsCloudPC.psd1'
$PublicPath = Join-Path $RepoRoot 'Public'
$TestsPath = Join-Path $RepoRoot 'Tests'
$RepoUrl = 'https://github.com/bwya77/PSWindowsCloudPC'
$GalleryUrl = 'https://www.powershellgallery.com/packages/WindowsCloudPC'
$CodeFence = '```'

function New-Directory {
    param([Parameter(Mandatory)][string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function ConvertTo-Slug {
    param([Parameter(Mandatory)][string]$Value)
    ($Value.ToLowerInvariant() -replace '[^a-z0-9]+','-' -replace '(^-|-$)','')
}

function ConvertTo-YamlString {
    param([AllowNull()][string]$Value)
    if ($null -eq $Value) { return '""' }
    '"' + ($Value -replace '\\','\\' -replace '"','\"') + '"'
}

function Get-CommentHelpBlock {
    param([Parameter(Mandatory)][string]$Path)

    $source = Get-Content -Path $Path -Raw
    $match = [regex]::Match($source, '(?s)<#(.*?)#>')
    $parameters = @{}
    $examples = [System.Collections.Generic.List[object]]::new()
    $synopsis = [System.Collections.Generic.List[string]]::new()
    $description = [System.Collections.Generic.List[string]]::new()

    if (-not $match.Success) {
        return [pscustomobject]@{
            Synopsis = ''
            Description = ''
            Parameters = $parameters
            Examples = @()
        }
    }

    $currentSection = $null
    $currentParameter = $null
    $currentExample = $null

    foreach ($rawLine in ($match.Groups[1].Value -split "`r?`n")) {
        $line = ($rawLine.TrimEnd() -replace '^\s+','')
        if ($line -match '^\.(\w+)(?:\s+(.+))?$') {
            $currentSection = $matches[1].ToUpperInvariant()
            $currentParameter = $null
            $currentExample = $null

            if ($currentSection -eq 'PARAMETER') {
                $currentParameter = $matches[2].Trim()
                if (-not $parameters.ContainsKey($currentParameter)) {
                    $parameters[$currentParameter] = [System.Collections.Generic.List[string]]::new()
                }
            }
            elseif ($currentSection -eq 'EXAMPLE') {
                $currentExample = [System.Collections.Generic.List[string]]::new()
                $examples.Add($currentExample)
            }
            continue
        }

        switch ($currentSection) {
            'SYNOPSIS' { $synopsis.Add($line) }
            'DESCRIPTION' { $description.Add($line) }
            'PARAMETER' {
                if ($currentParameter) { $parameters[$currentParameter].Add($line) }
            }
            'EXAMPLE' {
                if ($null -ne $currentExample) { $currentExample.Add($line) }
            }
        }
    }

    $parameterText = @{}
    foreach ($key in $parameters.Keys) {
        $parameterText[$key] = ((@($parameters[$key]) -join "`n").Trim())
    }

    $exampleObjects = foreach ($exampleLines in $examples) {
        $lines = @($exampleLines)
        while ($lines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($lines[0])) {
            $lines = @($lines | Select-Object -Skip 1)
        }
        while ($lines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($lines[-1])) {
            $lines = @($lines | Select-Object -First ($lines.Count - 1))
        }

        $firstBlank = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ([string]::IsNullOrWhiteSpace($lines[$i])) {
                $firstBlank = $i
                break
            }
        }

        if ($firstBlank -gt 0) {
            $code = (@($lines | Select-Object -First $firstBlank) -join "`n").Trim()
            $remarks = (@($lines | Select-Object -Skip ($firstBlank + 1)) -join "`n").Trim()
        }
        else {
            $code = ($lines -join "`n").Trim()
            $remarks = ''
        }

        [pscustomobject]@{
            Code = $code
            Remarks = $remarks
        }
    }

    [pscustomobject]@{
        Synopsis = ((@($synopsis) -join "`n").Trim())
        Description = ((@($description) -join "`n").Trim())
        Parameters = $parameterText
        Examples = @($exampleObjects)
    }
}

function Get-GalleryStats {
    try {
        $module = Find-Module -Name WindowsCloudPC -Repository PSGallery -ErrorAction Stop
        [ordered]@{
            galleryVersion = $module.Version.ToString()
            downloadCount = if ($module.AdditionalMetadata.downloadCount) { [int]$module.AdditionalMetadata.downloadCount } else { $null }
            publishedDate = if ($module.PublishedDate) { ([datetimeoffset]$module.PublishedDate).UtcDateTime.ToString('o') } else { $null }
            source = 'PowerShellGallery'
        }
    }
    catch {
        Write-Warning "PowerShell Gallery stats unavailable: $($_.Exception.Message)"
        [ordered]@{
            galleryVersion = $null
            downloadCount = $null
            publishedDate = $null
            source = 'fallback'
        }
    }
}

function Get-GraphEndpointsFromSource {
    param([Parameter(Mandatory)][string]$Path)

    $source = Get-Content -Path $Path -Raw
    [regex]::Matches($source, 'https://graph\.microsoft\.com/[^"`''\s]+') |
        ForEach-Object {
            $_.Value -replace 'https://graph\.microsoft\.com/(beta|v1\.0)', '/$1' `
                     -replace '\$escapedCloudPcId', '{id}' `
                     -replace '\$escapedUserId', '{userId}' `
                     -replace '\$escapedId', '{id}' `
                     -replace '\$cloudPcId', '{id}'
        } |
        Select-Object -Unique
}

function ConvertTo-MarkdownTableValue {
    param([AllowNull()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    (ConvertTo-MdxText ($Value -replace '\|','\\|' -replace "`r?`n", '<br />')).Trim()
}

function ConvertTo-MdxText {
    param([AllowNull()][string]$Value)
    if ($null -eq $Value) { return '' }
    $Value -replace '\{','&#123;' -replace '\}','&#125;'
}

New-Directory -Path $DocsPath
New-Directory -Path (Split-Path $StatsPath -Parent)
Get-ChildItem -Path $DocsPath -Filter '*.md' -File -ErrorAction SilentlyContinue | Remove-Item -Force

Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module $ManifestPath -Force -ErrorAction Stop

$manifest = Import-PowerShellDataFile -Path $ManifestPath
$commands = @(Get-Command -Module WindowsCloudPC -CommandType Function | Sort-Object Name)
$testSpecCount = @(Select-String -Path (Join-Path $TestsPath '*.ps1') -Pattern '^\s*It\s+[''"]' -ErrorAction SilentlyContinue).Count
$gallery = Get-GalleryStats

$stats = [ordered]@{
    moduleVersion = $manifest.ModuleVersion
    galleryVersion = $gallery.galleryVersion
    downloadCount = $gallery.downloadCount
    publishedDate = $gallery.publishedDate
    commandCount = $commands.Count
    testSpecCount = $testSpecCount
    repositoryUrl = $RepoUrl
    galleryUrl = $GalleryUrl
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    statsSource = $gallery.source
}
$stats | ConvertTo-Json -Depth 6 | Set-Content -Path $StatsPath -Encoding utf8NoBOM

$indexRows = foreach ($command in $commands) {
    $sourceFile = Join-Path $PublicPath ($command.Name + '.ps1')
    $help = Get-CommentHelpBlock -Path $sourceFile
    '| [' + $command.Name + '](/docs/commands/' + (ConvertTo-Slug $command.Name) + ') | ' +
        (ConvertTo-MarkdownTableValue $help.Synopsis) + ' | ' +
        $(if ($command.Verb -in @('Restart','Invoke','New','Set','Remove','Clear')) { 'Action' } else { 'Read' }) + ' |'
}

$index = @"
---
id: index
title: Command reference
description: Public command reference for the WindowsCloudPC PowerShell module.
slug: /commands/
---

# Command reference

These pages are generated from the module's comment-based help each time the Docusaurus site builds.

| Command | Summary | Type |
| --- | --- | --- |
$($indexRows -join "`n")
"@
Set-Content -Path (Join-Path $DocsPath 'index.md') -Value $index -Encoding utf8NoBOM

foreach ($command in $commands) {
    $sourceFile = Join-Path $PublicPath ($command.Name + '.ps1')
    $help = Get-CommentHelpBlock -Path $sourceFile
    $synopsis = if ($help.Synopsis) { $help.Synopsis } else { "Reference for $($command.Name)." }
    $description = if ($help.Description) { $help.Description } else { 'No detailed description is available yet.' }
    $mdxSynopsis = ConvertTo-MdxText $synopsis
    $mdxDescription = ConvertTo-MdxText $description
    $syntax = (Get-Command -Name $command.Name -Syntax) -join "`n`n"
    $commonParameters = @(
        'Verbose','Debug','ErrorAction','WarningAction','InformationAction',
        'ProgressAction','ErrorVariable','WarningVariable','InformationVariable',
        'OutVariable','OutBuffer','PipelineVariable','WhatIf','Confirm'
    )

    $parameterRows = foreach ($parameter in ($command.Parameters.Values | Sort-Object Name)) {
        if ($parameter.Name -in $commonParameters) { continue }
        $isMandatory = @($parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }) | Select-Object -First 1
        $aliases = if ($parameter.Aliases.Count -gt 0) { '`' + ($parameter.Aliases -join '`, `') + '`' } else { '' }
        $parameterDescription = if ($help.Parameters.ContainsKey($parameter.Name)) { $help.Parameters[$parameter.Name] } else { '' }
        '| `' + $parameter.Name + '` | `' + $parameter.ParameterType.Name + '` | ' +
            $(if ($isMandatory) { 'Yes' } else { 'No' }) + ' | ' +
            (ConvertTo-MarkdownTableValue $aliases) + ' | ' +
            (ConvertTo-MarkdownTableValue $parameterDescription) + ' |'
    }
    if (-not $parameterRows) {
        $parameterRows = '| None |  |  |  | This command has no custom parameters. |'
    }

    $endpoints = @(Get-GraphEndpointsFromSource -Path $sourceFile)
    $endpointText = if ($endpoints.Count -gt 0) {
        "${CodeFence}text`n$($endpoints -join "`n")`n${CodeFence}"
    }
    else {
        'Endpoint details are described in the source and examples.'
    }

    $exampleSections = [System.Collections.Generic.List[string]]::new()
    $exampleNumber = 0
    foreach ($example in @($help.Examples)) {
        $exampleNumber++
        $remarks = if ($example.Remarks) { "`n$($example.Remarks)`n" } else { '' }
        $remarks = ConvertTo-MdxText $remarks
        $exampleSections.Add(@"
## Example $exampleNumber

${CodeFence}powershell
$($example.Code)
${CodeFence}
$remarks
"@)
    }
    if ($exampleSections.Count -eq 0) {
        $exampleSections.Add('No examples are available yet.')
    }

    $content = @"
---
id: $(ConvertTo-Slug $command.Name)
title: $($command.Name)
description: $(ConvertTo-YamlString $synopsis)
---

# $($command.Name)

$mdxSynopsis

## Description

$mdxDescription

## Syntax

${CodeFence}powershell
$syntax
${CodeFence}

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
$($parameterRows -join "`n")

## Graph endpoints

$endpointText

$($exampleSections -join "`n")

## Source

[View $($command.Name).ps1 on GitHub]($RepoUrl/blob/main/Public/$($command.Name).ps1)
"@
    Set-Content -Path (Join-Path $DocsPath "$((ConvertTo-Slug $command.Name)).md") -Value $content -Encoding utf8NoBOM
}

Write-Host "Generated $($commands.Count) Docusaurus command pages in $DocsPath" -ForegroundColor Green
Write-Host "Wrote documentation stats to $StatsPath" -ForegroundColor Green
