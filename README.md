# WindowsCloudPC

[![CI](https://github.com/bwya77/PSWindowsCloudPC/actions/workflows/ci.yml/badge.svg)](https://github.com/bwya77/PSWindowsCloudPC/actions/workflows/ci.yml)
[![Release](https://github.com/bwya77/PSWindowsCloudPC/actions/workflows/release.yml/badge.svg)](https://github.com/bwya77/PSWindowsCloudPC/actions/workflows/release.yml)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/WindowsCloudPC.svg)](https://www.powershellgallery.com/packages/WindowsCloudPC)
[![Downloads](https://img.shields.io/powershellgallery/dt/WindowsCloudPC.svg)](https://www.powershellgallery.com/packages/WindowsCloudPC)

PowerShell module for managing and querying Windows 365 Cloud PCs via Microsoft Graph (beta).

## Status

Early — read-only functions only.

## Requirements

- PowerShell 7+
- `Microsoft.Graph.Authentication` module (auto-imported by `Connect-CloudPC`)
- Delegated Graph scopes (requested automatically by `Connect-CloudPC`):
  - `CloudPC.Read.All`
  - `DeviceManagementManagedDevices.Read.All`
  - `User.Read.All`
  - `Group.Read.All`

## Install

```powershell
Install-Module WindowsCloudPC -Scope CurrentUser
```

Or for development against the repo:

```powershell
git clone https://github.com/bwya77/PSWindowsCloudPC.git
Import-Module .\PSWindowsCloudPC\WindowsCloudPC.psd1 -Force
```

## Functions

| Function | Purpose |
| --- | --- |
| `Connect-CloudPC` | Idempotent Graph sign-in with the right scopes. |
| `Get-CloudPC` | List Cloud PCs (filter by policy, user, or type). Returns `WindowsCloudPC.CloudPC` objects with `.Raw` preserved. |
| `Get-CloudPCUsage` | For each Cloud PC, report who is signed in and whether it is `inUse` / `available`. Handles shared (frontline) and dedicated. |
| `Get-CloudPCProvisioningPolicy` | List provisioning policies with resolved assignment group names. `-IncludeCloudPCs` / `-IncludeCloudPCCount`. |

## Quick start

```powershell
Connect-CloudPC

# Everything in the tenant
Get-CloudPCUsage | Format-Table CloudPcName,ProvisioningType,UsageStatus,CurrentUserDisplayName,SessionStart

# Only Cloud PCs with an active session
Get-CloudPCUsage | Where-Object UsageStatus -eq 'inUse'

# One provisioning policy
Get-CloudPCProvisioningPolicy -Name 'W365-Flex-Shared' | Get-CloudPCUsage

# Pipeline composition
Get-CloudPC -Type Dedicated | Get-CloudPCUsage | Export-Csv .\dedicated-usage.csv -NoTypeInformation
```

## How `UsageStatus` is determined

| Provisioning type | Signal |
| --- | --- |
| Shared (Entra-group) | `connectivityResult.status` from the Cloud PC service. |
| Dedicated | Promoted to `inUse` when the matching Intune managedDevice has any `usersLoggedOn[]` entry. (The Cloud PC service rarely flips dedicated PCs to `inUse` on its own.) `unavailable` / `failed` are always preserved. |

## Releases

Every push to `main` that touches functional code (`Public/`, `Private/`, `WindowsCloudPC.psd1`, `WindowsCloudPC.psm1`) automatically:

1. Runs lint + Pester on Windows and Ubuntu.
2. Bumps the manifest `ModuleVersion` (patch by default).
3. Updates `CHANGELOG.md`, tags `vX.Y.Z`, and publishes to the PowerShell Gallery.

Force a `minor` or `major` bump from the **Actions → Release → Run workflow** button. Skip a release with `[skip release]` in the commit message.

## Roadmap

- `Get-CloudPCConnection` (connectivity health history)
- `Restart-CloudPC`, `Restore-CloudPC`, `Resize-CloudPC`, `Reprovision-CloudPC`
- `Get-CloudPCAuditEvent`
- Format file (`.format.ps1xml`) for default table views
- Authenticode signing via Azure Trusted Signing
