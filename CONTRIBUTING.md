# Contributing to WindowsCloudPC

Thanks for your interest! This module targets PowerShell 7+ and Microsoft Graph (beta).

## Dev loop

```powershell
git clone https://github.com/bwya77/WindowsCloudPC.git
cd WindowsCloudPC

# install deps + run the full pipeline locally (lint + test + stage build)
./build.ps1

# just lint
./build.ps1 -Task Lint

# just tests
./build.ps1 -Task Test
```

Tests mock `Invoke-MgGraphRequest`, so no tenant is required to run the suite.

## Standards

- All public functions must have comment-based help with `.SYNOPSIS`, `.DESCRIPTION`, and at least one `.EXAMPLE`.
- Use approved PowerShell verbs (`Get-Verb`).
- Singular nouns.
- Pipeline-friendly: prefer `ValueFromPipelineByPropertyName` for cross-function composition.
- All state-mutating functions must support `-WhatIf` / `-Confirm` via `[CmdletBinding(SupportsShouldProcess)]`.
- New public functions need a Pester test file under `Tests/<Function>.Tests.ps1`.
- PSScriptAnalyzer must pass with zero `Error` / `Warning` severity issues.

## PR checklist

- [ ] `./build.ps1` passes locally
- [ ] CHANGELOG.md updated under `[Unreleased]`
- [ ] New / changed public functions documented
- [ ] Tests added or updated

## Release

Releases are tag-triggered. Bumping `ModuleVersion` in `WindowsCloudPC.psd1`, moving the `[Unreleased]` section to a new `[X.Y.Z]` heading, and pushing a matching `vX.Y.Z` tag triggers the publish workflow.
