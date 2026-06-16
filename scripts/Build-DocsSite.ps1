#Requires -Version 7.0
<#
.SYNOPSIS
    Builds the static GitHub Pages documentation site for WindowsCloudPC.

.DESCRIPTION
    Generates a zero-dependency static documentation site from module metadata,
    comment-based help, README content, and PowerShell Gallery metadata.
#>
[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'Output\Site')
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent
$ManifestPath = Join-Path $RepoRoot 'WindowsCloudPC.psd1'
$ModulePath = $ManifestPath
$PublicPath = Join-Path $RepoRoot 'Public'
$TestsPath = Join-Path $RepoRoot 'Tests'
$RepoUrl = 'https://github.com/bwya77/PSWindowsCloudPC'
$GalleryUrl = 'https://www.powershellgallery.com/packages/WindowsCloudPC'
$PagesUrl = 'https://bwya77.github.io/PSWindowsCloudPC/'

function New-Directory {
    param([Parameter(Mandatory)][string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function ConvertTo-HtmlText {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return '' }
    [System.Net.WebUtility]::HtmlEncode(($Value | Out-String).Trim())
}

function ConvertTo-Slug {
    param([Parameter(Mandatory)][string]$Value)
    ($Value.ToLowerInvariant() -replace '[^a-z0-9]+','-' -replace '(^-|-$)','')
}

function Join-HelpText {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return '' }
    if ($Value -is [string]) { return $Value.Trim() }
    if ($Value.PSObject.Properties.Name -contains 'Text') {
        return (@($Value.Text) | Where-Object { $_ } | ForEach-Object { $_.ToString().Trim() }) -join "`n"
    }
    (@($Value) | Where-Object { $_ } | ForEach-Object { $_.ToString().Trim() }) -join "`n"
}

function ConvertTo-Paragraphs {
    param([AllowNull()][string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '<p>No detailed description is available yet.</p>' }
    $blocks = $Text -split "(`r?`n){2,}" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    ($blocks | ForEach-Object {
        '<p>' + (ConvertTo-HtmlText $_) + '</p>'
    }) -join "`n"
}

function ConvertTo-CodeBlock {
    param([AllowNull()][string]$Code)
    if ([string]::IsNullOrWhiteSpace($Code)) { return '' }
    '<pre><code>' + (ConvertTo-HtmlText $Code) + '</code></pre>'
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
            'SYNOPSIS' {
                $synopsis.Add($line)
            }
            'DESCRIPTION' {
                $description.Add($line)
            }
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
    $fallback = [ordered]@{
        GalleryVersion = $null
        DownloadCount = $null
        PublishedDate = $null
        ProjectUri = $null
        Source = 'fallback'
    }

    try {
        $module = Find-Module -Name WindowsCloudPC -Repository PSGallery -ErrorAction Stop
        return [ordered]@{
            GalleryVersion = $module.Version.ToString()
            DownloadCount = if ($module.AdditionalMetadata.downloadCount) { [int]$module.AdditionalMetadata.downloadCount } else { $null }
            PublishedDate = if ($module.PublishedDate) { ([datetimeoffset]$module.PublishedDate).UtcDateTime.ToString('o') } else { $null }
            ProjectUri = if ($module.ProjectUri) { $module.ProjectUri.ToString() } else { $null }
            Source = 'PowerShellGallery'
        }
    }
    catch {
        Write-Warning "PowerShell Gallery stats unavailable: $($_.Exception.Message)"
        return $fallback
    }
}

function New-SitePage {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][string]$Body,
        [Parameter(Mandatory)][string]$Path,
        [string]$Section = 'Docs'
    )

    New-Directory -Path (Split-Path $Path -Parent)
    $relativeRoot = [System.IO.Path]::GetRelativePath(
        (Resolve-Path -Path (Split-Path $Path -Parent)).Path,
        (Resolve-Path -Path $OutputPath).Path
    ).Replace('\','/')
    if ($relativeRoot -eq '.') { $relativeRoot = '.' }

    $html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="$(ConvertTo-HtmlText $Description)">
  <title>$(ConvertTo-HtmlText $Title) - WindowsCloudPC</title>
  <link rel="stylesheet" href="$relativeRoot/assets/site.css">
  <script defer src="$relativeRoot/assets/site.js"></script>
</head>
<body>
  <header class="topbar">
    <a class="brand" href="$relativeRoot/index.html">
      <span class="brand-mark">W365</span>
      <span>
        <strong>WindowsCloudPC</strong>
        <small>PowerShell module docs</small>
      </span>
    </a>
    <nav class="topnav" aria-label="Primary">
      <a href="$relativeRoot/docs/getting-started.html">Get started</a>
      <a href="$relativeRoot/docs/functions/index.html">Commands</a>
      <a href="$relativeRoot/docs/examples.html">Examples</a>
      <a href="$GalleryUrl">Gallery</a>
      <a href="$RepoUrl">GitHub</a>
    </nav>
  </header>
  <div class="shell">
    <aside class="sidebar">
      <div class="sidebar-title">$Section</div>
      <input class="search" type="search" placeholder="Search commands" aria-label="Search commands" data-search>
      <nav class="sidebar-nav" aria-label="Documentation">
        <a href="$relativeRoot/docs/getting-started.html">Getting started</a>
        <a href="$relativeRoot/docs/permissions.html">Permissions</a>
        <a href="$relativeRoot/docs/examples.html">Examples</a>
        <a href="$relativeRoot/docs/functions/index.html">Command reference</a>
      </nav>
      <div class="search-results" data-search-results></div>
    </aside>
    <main class="content">
$Body
    </main>
  </div>
</body>
</html>
"@

    Set-Content -Path $Path -Value $html -Encoding utf8NoBOM
}

function New-FunctionDoc {
    param(
        [Parameter(Mandatory)][System.Management.Automation.CommandInfo]$Command,
        [Parameter(Mandatory)][string]$Path
    )

    $sourceFile = Join-Path $PublicPath ($Command.Name + '.ps1')
    $parsedHelp = Get-CommentHelpBlock -Path $sourceFile
    $synopsis = $parsedHelp.Synopsis
    if ([string]::IsNullOrWhiteSpace($synopsis) -or $synopsis -eq $Command.Name) {
        $synopsis = 'No synopsis is available yet.'
    }
    $description = $parsedHelp.Description
    $syntaxText = (Get-Command -Name $Command.Name -Syntax) -join "`n"
    $paramHelp = $parsedHelp.Parameters

    $commonParameters = @(
        'Verbose','Debug','ErrorAction','WarningAction','InformationAction',
        'ProgressAction','ErrorVariable','WarningVariable','InformationVariable',
        'OutVariable','OutBuffer','PipelineVariable','WhatIf','Confirm'
    )

    $parameterRows = foreach ($parameter in ($Command.Parameters.Values | Sort-Object Name)) {
        if ($parameter.Name -in $commonParameters) { continue }
        $isMandatory = @($parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }) | Select-Object -First 1
        $aliases = if ($parameter.Aliases.Count -gt 0) { '`' + ($parameter.Aliases -join '`, `') + '`' } else { '' }
        $descriptionText = if ($paramHelp.ContainsKey($parameter.Name)) { $paramHelp[$parameter.Name] } else { '' }
        '<tr><td><code>' + (ConvertTo-HtmlText $parameter.Name) + '</code></td><td><code>' +
            (ConvertTo-HtmlText $parameter.ParameterType.Name) + '</code></td><td>' +
            $(if ($isMandatory) { 'Yes' } else { 'No' }) + '</td><td>' +
            (ConvertTo-HtmlText $aliases) + '</td><td>' +
            (ConvertTo-HtmlText $descriptionText) + '</td></tr>'
    }

    if (-not $parameterRows) {
        $parameterRows = '<tr><td colspan="5">No custom parameters.</td></tr>'
    }

    $exampleNumber = 0
    $examples = foreach ($example in @($parsedHelp.Examples)) {
        $exampleNumber++
        $title = "Example $exampleNumber"
        $code = $example.Code
        $remarks = $example.Remarks
        @"
<section class="example">
  <h3>$(ConvertTo-HtmlText $title)</h3>
  $(ConvertTo-CodeBlock $code)
  $(ConvertTo-Paragraphs $remarks)
</section>
"@
    }
    if (-not $examples) {
        $examples = '<p>No examples are available yet.</p>'
    }

    $sourceLink = "$RepoUrl/blob/main/Public/$($Command.Name).ps1"
    $verbClass = if ($Command.Verb -in @('Restart','Invoke','New','Set','Remove','Clear')) { 'write' } else { 'read' }
    $verbLabel = if ($verbClass -eq 'write') { 'Action command' } else { 'Read command' }

    $endpointMatches = @()
    if (Test-Path $sourceFile) {
        $source = Get-Content -Path $sourceFile -Raw
        $endpointMatches = [regex]::Matches($source, 'https://graph\.microsoft\.com/[^"`''\s]+') |
            ForEach-Object {
                $_.Value -replace 'https://graph\.microsoft\.com/(beta|v1\.0)', '/$1' `
                         -replace '\$escapedCloudPcId', '{id}' `
                         -replace '\$escapedUserId', '{userId}' `
                         -replace '\$escapedId', '{id}'
            } |
            Select-Object -Unique
    }
    $endpointHtml = if ($endpointMatches) {
        '<ul class="endpoint-list">' + (($endpointMatches | ForEach-Object { '<li><code>' + (ConvertTo-HtmlText $_) + '</code></li>' }) -join '') + '</ul>'
    }
    else {
        '<p>Endpoint details are described in the synopsis and examples.</p>'
    }

    $body = @"
<article class="doc">
  <div class="eyebrow">Command reference</div>
  <h1>$($Command.Name)</h1>
  <p class="lead">$(ConvertTo-HtmlText $synopsis)</p>
  <div class="meta-row">
    <span class="pill $verbClass">$verbLabel</span>
    <span class="pill">Verb: $($Command.Verb)</span>
    <span class="pill">Noun: $($Command.Noun)</span>
  </div>

  <h2>Description</h2>
  $(ConvertTo-Paragraphs $description)

  <h2>Syntax</h2>
  $(ConvertTo-CodeBlock $syntaxText)

  <h2>Parameters</h2>
  <div class="table-wrap">
    <table>
      <thead><tr><th>Name</th><th>Type</th><th>Required</th><th>Aliases</th><th>Description</th></tr></thead>
      <tbody>
        $($parameterRows -join "`n")
      </tbody>
    </table>
  </div>

  <h2>Graph endpoints</h2>
  $endpointHtml

  <h2>Examples</h2>
  $($examples -join "`n")

  <h2>Source</h2>
  <p><a href="$sourceLink">View $($Command.Name).ps1 on GitHub</a></p>
</article>
"@

    New-SitePage -Title $Command.Name -Description $synopsis -Body $body -Path $Path -Section 'Command reference'
}

if (Test-Path $OutputPath) {
    Remove-Item -Path $OutputPath -Recurse -Force
}
New-Directory -Path $OutputPath
New-Directory -Path (Join-Path $OutputPath 'assets')
New-Directory -Path (Join-Path $OutputPath 'docs\functions')

$manifest = Import-PowerShellDataFile -Path $ManifestPath
Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module $ModulePath -Force -ErrorAction Stop
$commands = @(Get-Command -Module WindowsCloudPC -CommandType Function | Sort-Object Name)
$gallery = Get-GalleryStats
$testCount = if (Test-Path $TestsPath) {
    @(Select-String -Path (Join-Path $TestsPath '*.ps1') -Pattern '^\s*It\s+[''"]' -ErrorAction SilentlyContinue).Count
}
else {
    0
}

$stats = [ordered]@{
    ModuleName = $manifest.RootModule -replace '\.psm1$',''
    ManifestVersion = $manifest.ModuleVersion
    GalleryVersion = $gallery.GalleryVersion
    DownloadCount = $gallery.DownloadCount
    PublishedDate = $gallery.PublishedDate
    CommandCount = $commands.Count
    TestCount = $testCount
    RepositoryUrl = $RepoUrl
    GalleryUrl = $GalleryUrl
    GeneratedAt = (Get-Date).ToUniversalTime().ToString('o')
    StatsSource = $gallery.Source
}
$stats | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $OutputPath 'stats.json') -Encoding utf8NoBOM

$searchIndex = foreach ($command in $commands) {
    $sourceFile = Join-Path $PublicPath ($command.Name + '.ps1')
    $parsedHelp = Get-CommentHelpBlock -Path $sourceFile
    [ordered]@{
        name = $command.Name
        synopsis = $parsedHelp.Synopsis
        href = "docs/functions/$($command.Name).html"
        verb = $command.Verb
        noun = $command.Noun
    }
}
$searchIndex | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $OutputPath 'assets\search-index.json') -Encoding utf8NoBOM

$css = @'
:root {
  --bg: #0b1220;
  --panel: #101a2f;
  --panel-2: #13213b;
  --text: #e8eefc;
  --muted: #9fb0d0;
  --brand: #67e8f9;
  --brand-2: #60a5fa;
  --border: rgba(255,255,255,.12);
  --code: #07101f;
  --ok: #86efac;
  --warn: #fbbf24;
}
* { box-sizing: border-box; }
body {
  margin: 0;
  font: 16px/1.6 "Segoe UI", system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
  color: var(--text);
  background:
    radial-gradient(circle at top left, rgba(96,165,250,.22), transparent 32rem),
    linear-gradient(180deg, #0b1220 0%, #0f172a 100%);
}
a { color: var(--brand); text-decoration: none; }
a:hover { text-decoration: underline; }
.topbar {
  position: sticky; top: 0; z-index: 10;
  display: flex; justify-content: space-between; align-items: center;
  padding: .85rem 1.25rem;
  background: rgba(11,18,32,.9);
  border-bottom: 1px solid var(--border);
  backdrop-filter: blur(14px);
}
.brand { display: flex; gap: .75rem; align-items: center; color: var(--text); }
.brand:hover { text-decoration: none; }
.brand small { display: block; color: var(--muted); margin-top: -.2rem; }
.brand-mark {
  display: inline-grid; place-items: center;
  width: 2.5rem; height: 2.5rem; border-radius: .8rem;
  color: #06111f; background: linear-gradient(135deg, var(--brand), var(--brand-2));
  font-weight: 800; font-size: .8rem;
}
.topnav { display: flex; gap: 1rem; flex-wrap: wrap; }
.topnav a { color: var(--muted); font-weight: 600; }
.shell { display: grid; grid-template-columns: 18rem minmax(0, 1fr); min-height: calc(100vh - 4.25rem); }
.sidebar {
  border-right: 1px solid var(--border);
  padding: 1.25rem;
  background: rgba(16,26,47,.55);
}
.sidebar-title { color: var(--muted); text-transform: uppercase; letter-spacing: .12em; font-size: .75rem; font-weight: 800; margin-bottom: .75rem; }
.search {
  width: 100%; padding: .7rem .8rem; border-radius: .75rem;
  border: 1px solid var(--border); background: var(--code); color: var(--text);
}
.sidebar-nav, .search-results { display: grid; gap: .45rem; margin-top: 1rem; }
.sidebar-nav a, .search-results a {
  padding: .55rem .65rem; border-radius: .6rem; color: var(--muted);
}
.sidebar-nav a:hover, .search-results a:hover { background: var(--panel-2); color: var(--text); text-decoration: none; }
.content { width: min(100%, 76rem); padding: 2rem clamp(1rem, 4vw, 4rem); }
.hero {
  padding: clamp(2rem, 6vw, 5rem);
  border: 1px solid var(--border);
  border-radius: 1.5rem;
  background: linear-gradient(135deg, rgba(19,33,59,.94), rgba(14,23,42,.82));
  box-shadow: 0 30px 80px rgba(0,0,0,.25);
}
.eyebrow { color: var(--brand); text-transform: uppercase; letter-spacing: .14em; font-size: .78rem; font-weight: 800; }
h1 { font-size: clamp(2.25rem, 5vw, 4.7rem); line-height: 1; margin: .6rem 0 1rem; }
h2 { margin-top: 2.25rem; padding-top: .5rem; border-top: 1px solid var(--border); }
h3 { margin-top: 1.4rem; }
.lead { color: var(--muted); font-size: 1.18rem; max-width: 68ch; }
.actions { display: flex; gap: .75rem; flex-wrap: wrap; margin-top: 1.5rem; }
.button {
  display: inline-flex; align-items: center; justify-content: center;
  padding: .78rem 1rem; border-radius: .8rem; font-weight: 800;
  color: #06111f; background: linear-gradient(135deg, var(--brand), var(--brand-2));
}
.button.secondary { color: var(--text); background: var(--panel-2); border: 1px solid var(--border); }
.button:hover { text-decoration: none; filter: brightness(1.08); }
.stats-grid, .card-grid {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(13rem, 1fr));
  gap: 1rem; margin: 1.25rem 0 2rem;
}
.stat, .card {
  padding: 1rem; border: 1px solid var(--border); border-radius: 1rem;
  background: rgba(16,26,47,.72);
}
.stat strong { display: block; font-size: 2rem; line-height: 1.1; }
.stat span, .card p { color: var(--muted); }
.doc { max-width: 72rem; }
.meta-row { display: flex; gap: .6rem; flex-wrap: wrap; margin: 1rem 0; }
.pill { display: inline-flex; align-items: center; padding: .28rem .6rem; border: 1px solid var(--border); border-radius: 999px; color: var(--muted); background: rgba(255,255,255,.04); }
.pill.read { color: var(--ok); }
.pill.write { color: var(--warn); }
pre {
  overflow-x: auto; padding: 1rem; border-radius: 1rem;
  border: 1px solid var(--border); background: var(--code);
}
code { font-family: "Cascadia Code", Consolas, monospace; }
table { width: 100%; border-collapse: collapse; }
th, td { padding: .75rem; border-bottom: 1px solid var(--border); text-align: left; vertical-align: top; }
th { color: var(--brand); font-size: .85rem; text-transform: uppercase; letter-spacing: .08em; }
.table-wrap { overflow-x: auto; border: 1px solid var(--border); border-radius: 1rem; }
.endpoint-list { display: grid; gap: .5rem; padding-left: 1.2rem; }
.command-list { display: grid; gap: .8rem; }
.command-list a {
  display: block; padding: 1rem; border: 1px solid var(--border); border-radius: 1rem; background: rgba(16,26,47,.72);
}
.command-list a:hover { text-decoration: none; border-color: rgba(103,232,249,.5); }
.command-list strong { display: block; color: var(--text); }
.command-list span { color: var(--muted); }
@media (max-width: 860px) {
  .topbar { align-items: flex-start; gap: 1rem; flex-direction: column; }
  .shell { grid-template-columns: 1fr; }
  .sidebar { position: static; border-right: 0; border-bottom: 1px solid var(--border); }
}
'@
Set-Content -Path (Join-Path $OutputPath 'assets\site.css') -Value $css -Encoding utf8NoBOM

$js = @'
async function loadJson(url) {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Failed to load ${url}`);
  return await response.json();
}

function formatNumber(value) {
  if (value === null || value === undefined || value === '') return 'n/a';
  const number = Number(value);
  return Number.isFinite(number) ? number.toLocaleString() : value;
}

async function hydrateStats() {
  try {
    const stats = await loadJson('./stats.json').catch(() => loadJson('../stats.json')).catch(() => loadJson('../../stats.json'));
    document.querySelectorAll('[data-stat]').forEach((node) => {
      const key = node.getAttribute('data-stat');
      node.textContent = key.toLowerCase().includes('count') ? formatNumber(stats[key]) : (stats[key] ?? 'n/a');
    });
  } catch {}
}

async function wireSearch() {
  const inputs = document.querySelectorAll('[data-search]');
  if (inputs.length === 0) return;
  let index;
  try {
    index = await loadJson('./assets/search-index.json').catch(() => loadJson('../assets/search-index.json')).catch(() => loadJson('../../assets/search-index.json'));
  } catch {
    return;
  }
  inputs.forEach((input) => {
    const results = input.closest('.sidebar')?.querySelector('[data-search-results]');
    input.addEventListener('input', () => {
      const q = input.value.toLowerCase().trim();
      if (!results) return;
      if (!q) {
        results.innerHTML = '';
        return;
      }
      const matches = index.filter((item) =>
        item.name.toLowerCase().includes(q) ||
        (item.synopsis || '').toLowerCase().includes(q) ||
        (item.verb || '').toLowerCase().includes(q) ||
        (item.noun || '').toLowerCase().includes(q)
      ).slice(0, 8);
      results.innerHTML = matches.map((item) => `<a href="${location.pathname.includes('/docs/functions/') ? item.name + '.html' : (location.pathname.endsWith('/index.html') || location.pathname.endsWith('/') ? item.href : '../' + item.href.replace('docs/', ''))}"><strong>${item.name}</strong><br><small>${item.synopsis || ''}</small></a>`).join('');
    });
  });
}

hydrateStats();
wireSearch();
'@
Set-Content -Path (Join-Path $OutputPath 'assets\site.js') -Value $js -Encoding utf8NoBOM

$commandCards = foreach ($command in $commands) {
    $sourceFile = Join-Path $PublicPath ($command.Name + '.ps1')
    $parsedHelp = Get-CommentHelpBlock -Path $sourceFile
    $synopsis = $parsedHelp.Synopsis
    '<a href="functions/' + $command.Name + '.html"><strong>' + (ConvertTo-HtmlText $command.Name) + '</strong><span>' + (ConvertTo-HtmlText $synopsis) + '</span></a>'
}

$indexBody = @"
<section class="hero">
  <div class="eyebrow">Windows 365 automation</div>
  <h1>PowerShell docs for WindowsCloudPC</h1>
  <p class="lead">A focused PowerShell module for querying, operating, and documenting Windows 365 Cloud PCs through Microsoft Graph beta APIs.</p>
  <div class="actions">
    <a class="button" href="docs/getting-started.html">Get started</a>
    <a class="button secondary" href="docs/functions/index.html">Browse commands</a>
    <a class="button secondary" href="$GalleryUrl">Install from PSGallery</a>
  </div>
</section>

<section class="stats-grid">
  <div class="stat"><span>PowerShell Gallery version</span><strong data-stat="GalleryVersion">$($stats.GalleryVersion)</strong></div>
  <div class="stat"><span>Total downloads</span><strong data-stat="DownloadCount">$($stats.DownloadCount)</strong></div>
  <div class="stat"><span>Public commands</span><strong data-stat="CommandCount">$($stats.CommandCount)</strong></div>
  <div class="stat"><span>Static test specs</span><strong data-stat="TestCount">$($stats.TestCount)</strong></div>
</section>

<section>
  <h2>What is available</h2>
  <div class="card-grid">
    <div class="card"><h3>Inventory</h3><p>List Cloud PCs, provisioning policies, supported regions, setting profiles, user settings, launch details, licensing allotments, and restore point snapshots.</p></div>
    <div class="card"><h3>Operations</h3><p>Restart Cloud PCs, reprovision individual or policy-scoped Cloud PCs, and create restore point snapshots across single, user, policy, or tenant scopes.</p></div>
    <div class="card"><h3>Usage insights</h3><p>Report active sessions, sign-in status, last active time, idle Cloud PCs, and recent remote action results.</p></div>
  </div>
</section>

<section>
  <h2>Install</h2>
  $(ConvertTo-CodeBlock 'Install-Module WindowsCloudPC -Scope CurrentUser')
  <p>Then connect to Microsoft Graph:</p>
  $(ConvertTo-CodeBlock 'Connect-CloudPC')
</section>
"@
New-SitePage -Title 'WindowsCloudPC documentation' -Description 'Generated documentation for the WindowsCloudPC PowerShell module.' -Body $indexBody -Path (Join-Path $OutputPath 'index.html') -Section 'Overview'

$gettingStartedBody = @"
<article class="doc">
  <div class="eyebrow">Guide</div>
  <h1>Getting started</h1>
  <p class="lead">Install the module, connect to Microsoft Graph, and run your first Windows 365 Cloud PC queries.</p>
  <h2>Install from PowerShell Gallery</h2>
  $(ConvertTo-CodeBlock 'Install-Module WindowsCloudPC -Scope CurrentUser')
  <h2>Import from source</h2>
  $(ConvertTo-CodeBlock "git clone $RepoUrl.git`nImport-Module .\PSWindowsCloudPC\WindowsCloudPC.psd1 -Force")
  <h2>Connect</h2>
  $(ConvertTo-CodeBlock 'Connect-CloudPC')
  <p>Connect-CloudPC requests the read scopes needed by the module by default. Write-action cmdlets request additional scopes only when needed.</p>
  <h2>First queries</h2>
  $(ConvertTo-CodeBlock "Get-CloudPC | Format-Table Name,ProvisioningStatus,AssignedUserUpn`nGet-CloudPCUsage | Format-Table CloudPcName,UsageStatus,DaysSinceLastSignIn`nGet-CloudPCByProvisioningPolicy | Format-Table DisplayName,ProvisioningType,CloudPCCount")
</article>
"@
New-SitePage -Title 'Getting started' -Description 'Install and start using WindowsCloudPC.' -Body $gettingStartedBody -Path (Join-Path $OutputPath 'docs\getting-started.html')

$permissionsBody = @"
<article class="doc">
  <div class="eyebrow">Reference</div>
  <h1>Permissions</h1>
  <p class="lead">WindowsCloudPC uses delegated Microsoft Graph scopes and asks for additional scopes only when a command needs them.</p>
  <h2>Default scopes</h2>
  <ul>
    <li><code>CloudPC.Read.All</code></li>
    <li><code>DeviceManagementManagedDevices.Read.All</code></li>
    <li><code>User.Read.All</code></li>
    <li><code>Group.Read.All</code></li>
  </ul>
  <h2>On-demand scopes</h2>
  <div class="table-wrap">
    <table>
      <thead><tr><th>Scope</th><th>Used by</th></tr></thead>
      <tbody>
        <tr><td><code>CloudPC.ReadWrite.All</code></td><td>Restart-CloudPC, Invoke-CloudPCReprovision, Invoke-CloudPCPolicyReprovision, New-CloudPCSnapshot</td></tr>
        <tr><td><code>CloudLicensing.Read</code></td><td>Get-CloudPCLicensingAllotment</td></tr>
      </tbody>
    </table>
  </div>
</article>
"@
New-SitePage -Title 'Permissions' -Description 'Microsoft Graph permissions used by WindowsCloudPC.' -Body $permissionsBody -Path (Join-Path $OutputPath 'docs\permissions.html')

$examplesBody = @"
<article class="doc">
  <div class="eyebrow">Recipes</div>
  <h1>Examples</h1>
  <p class="lead">Common command compositions for Windows 365 Cloud PC operations and reporting.</p>
  <h2>Find idle Cloud PCs</h2>
  $(ConvertTo-CodeBlock 'Get-CloudPCUsage | Where-Object DaysSinceLastSignIn -ge 14 | Sort-Object DaysSinceLastSignIn -Descending')
  <h2>List restore point snapshots for a user</h2>
  $(ConvertTo-CodeBlock "Get-CloudPCSnapshot -User 'user@contoso.com' -Verbose |`n    Format-Table CloudPcName,Status,SnapshotType,CreatedDateTime")
  <h2>Create snapshots for a provisioning policy</h2>
  $(ConvertTo-CodeBlock "New-CloudPCSnapshot -ProvisioningPolicyId '<policy-id>' `````n    -ExcludeCloudPC 'CPC-KEEP-01','user4@contoso.com' `````n    -Force |`n    Format-Table CloudPcName,AssignedUserUpn,Status,Excluded,ErrorMessage")
  <h2>Reprovision a policy except excluded Cloud PCs</h2>
  $(ConvertTo-CodeBlock "Invoke-CloudPCPolicyReprovision -ProvisioningPolicyId '<policy-id>' `````n    -ExcludeCloudPC 'CPC-KEEP-01','CPC-KEEP-02','cpc-id-3' `````n    -OsVersion windows11 -UserAccountType standardUser -Force")
  <h2>List licensing allotments</h2>
  $(ConvertTo-CodeBlock 'Get-CloudPCLicensingAllotment | Format-Table SkuPartNumber,AllottedUnits,ConsumedUnits,AvailableUnits')
</article>
"@
New-SitePage -Title 'Examples' -Description 'WindowsCloudPC PowerShell examples.' -Body $examplesBody -Path (Join-Path $OutputPath 'docs\examples.html')

$functionsBody = @"
<article class="doc">
  <div class="eyebrow">Reference</div>
  <h1>Command reference</h1>
  <p class="lead">$($commands.Count) public commands generated from the module's comment-based help.</p>
  <div class="command-list">
    $($commandCards -join "`n")
  </div>
</article>
"@
New-SitePage -Title 'Command reference' -Description 'All WindowsCloudPC public commands.' -Body $functionsBody -Path (Join-Path $OutputPath 'docs\functions\index.html') -Section 'Command reference'

foreach ($command in $commands) {
    New-FunctionDoc -Command $command -Path (Join-Path $OutputPath "docs\functions\$($command.Name).html")
}

Write-Host "Docs site generated at $OutputPath" -ForegroundColor Green
