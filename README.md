# WindowsCloudPC

[![CI](https://github.com/bwya77/PSWindowsCloudPC/actions/workflows/ci.yml/badge.svg)](https://github.com/bwya77/PSWindowsCloudPC/actions/workflows/ci.yml)
[![Release](https://github.com/bwya77/PSWindowsCloudPC/actions/workflows/release.yml/badge.svg)](https://github.com/bwya77/PSWindowsCloudPC/actions/workflows/release.yml)
[![Docs](https://github.com/bwya77/PSWindowsCloudPC/actions/workflows/pages.yml/badge.svg)](https://bwya77.github.io/PSWindowsCloudPC/)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/WindowsCloudPC.svg)](https://www.powershellgallery.com/packages/WindowsCloudPC)
[![Downloads](https://img.shields.io/powershellgallery/dt/WindowsCloudPC.svg)](https://www.powershellgallery.com/packages/WindowsCloudPC)

PowerShell module for managing and querying Windows 365 Cloud PCs via Microsoft Graph (beta).

Detailed Docusaurus documentation is published to GitHub Pages: <https://bwya77.github.io/PSWindowsCloudPC/>.

## Status

Early — read-only queries plus a small set of write actions (reboot and reprovision).

## Requirements

- PowerShell 7+
- `Microsoft.Graph.Authentication` module (auto-imported by `Connect-CloudPC`)
- Delegated Graph scopes (requested automatically by `Connect-CloudPC`):
  - `CloudPC.Read.All`
  - `DeviceManagementManagedDevices.Read.All`
  - `User.Read.All`
  - `Group.Read.All`
  - `CloudPC.ReadWrite.All` (added on-demand by reboot/reprovision cmdlets)

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
| `Get-CloudPCUsage` | For each Cloud PC, report who is signed in and whether it is `inUse` / `available`, plus `SignInStatus`, `DaysSinceLastSignIn`, and `LastActiveTime`. Works for shared **and** dedicated. |
| `Get-CloudPCProvisioningPolicy` | List provisioning policies with resolved assignment group names. |
| `Get-CloudPCByProvisioningPolicy` | One row per policy with a nested `CloudPCs` array and `CloudPCCount`. Answers "which Cloud PCs belong to which policy". |
| `Get-CloudPCLaunchDetail` | Get launch details for a Cloud PC, including the Graph launch URL, Windows 365 Switch compatibility, and a computed `ms-cloudpc:connect` Windows App URI when a username is available. Provisioning PCs return `LaunchDetailStatus = 'Unavailable'` instead of a noisy 404. |
| `Get-CloudPCLicensingAllotment` | List Microsoft Graph cloud licensing allotments from Graph beta. Supports single allotment lookup plus `$select`, `$expand`, `$filter`, `$top`, and `$apply` query shaping. |
| `Get-CloudPCRemoteActionResult` | Recent remote-action history (restart, reprovision, restore, …) for a Cloud PC, with `ActionState`, timestamps, and `HasDownTime`. Use right after `Restart-CloudPC` to confirm the action landed. |
| `Get-CloudPCSettingProfile` | List Windows 365 setting profiles from Graph beta. Use `-Id` for a single profile and `-IncludeDetails` to expand assignments and settings, including object and list setting children. |
| `Get-CloudPCSnapshot` | List Cloud PC restore point snapshots from Graph beta. Supports `-Id`, `-CloudPC` object or friendly name, `-User`, and `-All`, with friendly Cloud PC names and verbose progress output. |
| `Get-CloudPCSupportedRegion` | List Windows 365 supported Cloud PC regions from Graph beta, including region status, supported solution, region group, and geographic location type. Supports client-side filters for status, solution, region group, and geography. |
| `Get-CloudPCUserSetting` | List Windows 365 Cloud PC user settings from Graph beta, including reset, restore point, local admin, cross-region disaster recovery, notification, and assignment details. |
| `Invoke-CloudPCReprovision` | Reprovision one or more Cloud PCs via Graph. Pipeline-friendly, `SupportsShouldProcess` (defaults to `ConfirmImpact='High'`), optional `-OsVersion` / `-UserAccountType`, `-Force`, and `-PassThru`. |
| `Invoke-CloudPCPolicyReprovision` | Reprovision every Cloud PC in a provisioning policy, optionally excluding specific Cloud PCs by name, ID, managed device ID, Azure AD device ID, or assigned user UPN. Emits a target/result row for every included or excluded PC. |
| `New-CloudPCSnapshot` | Create Cloud PC restore point snapshots via Graph beta. Supports one Cloud PC by ID, object, or friendly name, plus `-All`, `-User`, and `-ProvisioningPolicyId` batch modes. Emits one result row per target. |
| `Restart-CloudPC` | Reboot one or more Cloud PCs via Graph. Pipeline-friendly, `SupportsShouldProcess` (defaults to `ConfirmImpact='High'`), `-Force` to skip the prompt, `-PassThru` for a result object. |

## Quick start

```powershell
Connect-CloudPC

# Everything in the tenant
Get-CloudPCUsage | Format-Table CloudPcName,ProvisioningType,UsageStatus,SignInStatus,DaysSinceLastSignIn,CurrentUserDisplayName,SessionStart

# Only Cloud PCs with an active session
Get-CloudPCUsage | Where-Object UsageStatus -eq 'inUse'

# Idle Cloud PCs (no sign-in in 14+ days)
Get-CloudPCUsage | Where-Object DaysSinceLastSignIn -ge 14 | Sort-Object DaysSinceLastSignIn -Descending

# Per-policy breakdown
Get-CloudPCByProvisioningPolicy | Format-Table DisplayName,ProvisioningType,CloudPCCount

# Drill into a single policy's Cloud PCs
Get-CloudPCByProvisioningPolicy |
    Select-Object DisplayName -ExpandProperty CloudPCs |
    Format-Table DisplayName,Name,ProvisioningStatus,AssignedUserUpn

# Pipeline composition
Get-CloudPC -Type Dedicated | Get-CloudPCUsage | Export-Csv .\dedicated-usage.csv -NoTypeInformation

# Get launch URLs and Windows App launch URIs for a user's Cloud PCs
Get-CloudPC -UserPrincipalName 'user@contoso.com' |
    Get-CloudPCLaunchDetail -UserId 'user@contoso.com' |
    Format-Table CloudPcName,LaunchDetailStatus,Windows365SwitchCompatible,WindowsAppLaunchUri

# List cloud licensing allotments
Get-CloudPCLicensingAllotment |
    Format-Table SkuPartNumber,AllottedUnits,ConsumedUnits,AvailableUnits,AssignableTo

# Get one cloud licensing allotment by ID
Get-CloudPCLicensingAllotment -Id '<allotment-id>' |
    Select-Object SkuPartNumber,AllottedUnits,ConsumedUnits,Services,Subscriptions

# Shape the beta allotments query with OData options
Get-CloudPCLicensingAllotment `
    -Select id,skuPartNumber,allottedUnits,consumedUnits `
    -Expand 'waitingMembers($select=id,waitingSinceDateTime)'

# List supported Windows 365 Cloud PC regions
Get-CloudPCSupportedRegion |
    Sort-Object DisplayName |
    Format-Table DisplayName,RegionStatus,RegionGroup,GeographicLocationType

# Find available regions in a specific region group
Get-CloudPCSupportedRegion -RegionStatus available -RegionGroup usEast

# List Cloud PC user settings
Get-CloudPCUserSetting |
    Format-Table DisplayName,ResetEnabled,UserRestoreEnabled,LocalAdminEnabled

# Get one user setting with assignments
Get-CloudPCUserSetting -Id '<user-setting-id>' -IncludeAssignments |
    Select-Object DisplayName,Assignments

# List Windows 365 setting profiles
Get-CloudPCSettingProfile |
    Format-Table DisplayName,ProfileType,TemplateId,IsAssigned,Priority

# Get one setting profile with assignments and expanded settings
Get-CloudPCSettingProfile -Id '<setting-profile-id>' -IncludeDetails |
    Select-Object DisplayName,Assignments,Settings

# List restore point snapshots for all Cloud PCs
Get-CloudPCSnapshot -All -Verbose |
    Format-Table CloudPcName,Status,SnapshotType,CreatedDateTime

# List restore point snapshots for all Cloud PCs assigned to a user
Get-CloudPCSnapshot -User 'user@contoso.com' -Verbose |
    Format-Table CloudPcName,Status,SnapshotType,CreatedDateTime

# List restore point snapshots for one Cloud PC by friendly name
Get-CloudPCSnapshot -CloudPC 'CFD-Vance-XS4KT' |
    Format-Table CloudPcName,Status,SnapshotType,CreatedDateTime

# Create a restore point snapshot for one Cloud PC by friendly name
New-CloudPCSnapshot -CloudPC 'CFD-Vance-XS4KT' -Force |
    Format-Table CloudPcName,Status,RequestedAt,ErrorMessage

# Create restore point snapshots for all Cloud PCs assigned to a user
New-CloudPCSnapshot -User 'user@contoso.com' -Force |
    Format-Table CloudPcName,AssignedUserUpn,Status,RequestedAt,ErrorMessage

# Create restore point snapshots for every Cloud PC in a provisioning policy except selected targets
New-CloudPCSnapshot -ProvisioningPolicyId '<policy-id>' `
    -ExcludeCloudPC 'CPC-KEEP-01','CPC-KEEP-02','cpc-id-3','user4@contoso.com' `
    -Force |
    Format-Table CloudPcName,AssignedUserUpn,ProvisioningPolicyName,Status,Excluded,ErrorMessage

# Reboot a single Cloud PC and confirm the action landed
$pc = Get-CloudPC | Where-Object Name -eq 'CFD-brad-TUFL7'
$pc | Restart-CloudPC -Force
$pc | Get-CloudPCRemoteActionResult | Where-Object ActionName -eq 'Restart'

# Reprovision a single Cloud PC and confirm the action landed
$pc | Invoke-CloudPCReprovision -OsVersion windows11 -UserAccountType standardUser -Force
$pc | Get-CloudPCRemoteActionResult | Where-Object ActionName -eq 'Reprovision'

# Reprovision every Cloud PC in a policy except a small exclusion list
Invoke-CloudPCPolicyReprovision -ProvisioningPolicyId '<policy-id>' `
    -ExcludeCloudPC 'CPC-KEEP-01','CPC-KEEP-02','cpc-id-3','user4@contoso.com' `
    -OsVersion windows11 -UserAccountType standardUser -Force |
    Format-Table CloudPcName,AssignedUserUpn,Status,Excluded,ErrorMessage

# Tenant-wide most-recent-action snapshot
Get-CloudPC | Get-CloudPCRemoteActionResult |
    Format-Table CloudPcName,ActionName,ActionState,StartDateTime,HasDownTime
```

## How `UsageStatus` is determined

`Get-CloudPCUsage` uses the Graph beta `/reports/getRealTimeRemoteConnectionStatus`
report as its **primary** signal for every Cloud PC (shared and dedicated). The
report's `SignInStatus` (`SignedIn` / `NotSignedIn`) maps to `UsageStatus`
(`inUse` / `available`), and the report also gives you `DaysSinceLastSignIn` and
`LastActiveTime` for free.

If the report endpoint is unreachable for a given PC, `Get-CloudPCUsage` falls
back to the Cloud PC's own `connectivityResult.status`. Cloud PCs that have
never been signed into (no sign-in history yet) are surfaced as
`available` / `NotSignedIn` rather than `unknown`.

## Releases

Every push to `main` that touches functional code (`Public/`, `Private/`, `WindowsCloudPC.psd1`, `WindowsCloudPC.psm1`) automatically:

1. Runs lint + Pester on Windows and Ubuntu.
2. Bumps the manifest `ModuleVersion` (patch by default).
3. Updates `CHANGELOG.md`, tags `vX.Y.Z`, and publishes to the PowerShell Gallery.

Force a `minor` or `major` bump from the **Actions → Release → Run workflow** button. Skip a release with `[skip release]` in the commit message.

## Roadmap

- `Get-CloudPCConnection` (connectivity health history)
- `Restore-CloudPC`, `Resize-CloudPC`
- `Get-CloudPCAuditEvent`
- Format file (`.format.ps1xml`) for default table views
- Authenticode signing via Azure Trusted Signing
