# WindowsCloudPC

[![CI](https://github.com/bwya77/PSWindowsCloudPC/actions/workflows/ci.yml/badge.svg)](https://github.com/bwya77/PSWindowsCloudPC/actions/workflows/ci.yml)
[![Release](https://github.com/bwya77/PSWindowsCloudPC/actions/workflows/release.yml/badge.svg)](https://github.com/bwya77/PSWindowsCloudPC/actions/workflows/release.yml)
[![Docs](https://github.com/bwya77/PSWindowsCloudPC/actions/workflows/pages.yml/badge.svg)](https://bwya77.github.io/PSWindowsCloudPC/)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/WindowsCloudPC.svg)](https://www.powershellgallery.com/packages/WindowsCloudPC)
[![Downloads](https://img.shields.io/powershellgallery/dt/WindowsCloudPC.svg)](https://www.powershellgallery.com/packages/WindowsCloudPC)

PowerShell module for managing and querying Windows 365 Cloud PCs via Microsoft Graph (beta).

Detailed Docusaurus documentation is published to GitHub Pages: <https://bwya77.github.io/PSWindowsCloudPC/>.

## Status

Early - read-only queries plus write actions for power-on, reboot, sync, local admin password rotation, reprovision, snapshots, provisioning policies, and maintenance windows.

## Requirements

- PowerShell 7+
- `Microsoft.Graph.Authentication` module (auto-imported by `Connect-CloudPC`)
- Delegated Graph scopes (requested automatically by `Connect-CloudPC`):
  - `CloudPC.Read.All`
  - `DeviceManagementManagedDevices.Read.All`
  - `User.Read.All`
  - `Group.Read.All`
  - `CloudPC.ReadWrite.All` (added on-demand by power-on/reboot/reprovision cmdlets)
  - `DeviceManagementManagedDevices.PrivilegedOperations.All` (added on-demand by `Sync-CloudPC` and `Reset-CloudPCLocalAdminPassword`)

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
| `Export-CloudPCProvisioningPolicy` | Export a provisioning policy to reusable JSON with a create-safe body and assignment targets. |
| `Get-CloudPC` | List Cloud PCs (filter by policy, user, or type). Returns `WindowsCloudPC.CloudPC` objects with `.Raw` preserved. |
| `Get-CloudPCUsage` | For each Cloud PC, report who is signed in and whether it is `inUse` / `available`, plus `SignInStatus`, `DaysSinceLastSignIn`, and `LastActiveTime`. Works for shared **and** dedicated. |
| `Get-CloudPCProvisioningPolicy` | List provisioning policies with resolved assignment group names. |
| `Get-CloudPCByProvisioningPolicy` | One row per policy with a nested `CloudPCs` array and `CloudPCCount`. Answers "which Cloud PCs belong to which policy". |
| `Get-CloudPCLaunchDetail` | Get launch details for a Cloud PC, including the Graph launch URL, Windows 365 Switch compatibility, and a computed `ms-cloudpc:connect` Windows App URI when a username is available. Provisioning PCs return `LaunchDetailStatus = 'Unavailable'` instead of a noisy 404. |
| `Get-CloudPCLicensingAllotment` | List Microsoft Graph cloud licensing allotments from Graph beta. Supports single allotment lookup plus `$select`, `$expand`, `$filter`, `$top`, and `$apply` query shaping. |
| `Get-CloudPCMaintenanceWindow` | List Cloud PC maintenance windows from Graph beta. Supports exact display name lookup, ID lookup, and optional assignment expansion with resolved group names. |
| `Get-CloudPCRemoteActionResult` | Recent remote-action history (restart, reprovision, restore, …) for a Cloud PC, with `ActionState`, timestamps, and `HasDownTime`. Use right after `Restart-CloudPC` to confirm the action landed. |
| `Get-CloudPCSettingProfile` | List Windows 365 setting profiles from Graph beta. Use `-Id` for a single profile and `-IncludeDetails` to expand assignments and settings, including object and list setting children. |
| `Get-CloudPCSnapshot` | List Cloud PC restore point snapshots from Graph beta. Supports `-Id`, `-CloudPC` object or friendly name, `-User`, and `-All`, with friendly Cloud PC names and verbose progress output. |
| `Get-CloudPCSupportedRegion` | List Windows 365 supported Cloud PC regions from Graph beta, including region status, supported solution, region group, and geographic location type. Supports client-side filters for status, solution, region group, and geography. |
| `Get-CloudPCUserSetting` | List Windows 365 Cloud PC user settings from Graph beta, including reset, restore point, local admin, cross-region disaster recovery, notification, and assignment details. |
| `Invoke-CloudPCReprovision` | Reprovision one or more Cloud PCs via Graph. Pipeline-friendly, `SupportsShouldProcess` (defaults to `ConfirmImpact='High'`), optional `-OsVersion` / `-UserAccountType`, `-Force`, and `-PassThru`. |
| `Invoke-CloudPCPolicyReprovision` | Reprovision every Cloud PC in a provisioning policy, optionally excluding specific Cloud PCs by name, ID, managed device ID, Azure AD device ID, or assigned user UPN. Emits a target/result row for every included or excluded PC. |
| `New-CloudPCMaintenanceWindow` | Create Cloud PC maintenance windows from weekday and weekend times, or custom schedule objects. Uses the portal-style weekday plus weekend payload, supports `-WhatIf`, two-hour minimum validation, optional group assignment, and result metadata. |
| `New-CloudPCProvisioningPolicy` | Create a provisioning policy from an export. Supports `-WhatIf`, display name and description overrides, and optional assignment recreation with `-Assign`. |
| `New-CloudPCSnapshot` | Create Cloud PC restore point snapshots via Graph beta. Supports one Cloud PC by ID, object, or friendly name, plus `-All`, `-User`, and `-ProvisioningPolicyId` batch modes. Emits one result row per target. |
| `Remove-CloudPCMaintenanceWindow` | Delete a Cloud PC maintenance window by ID, exact display name, or pipeline object. Clears assignments before delete to avoid Graph 409 conflicts. Supports `-WhatIf`, `-Confirm`, `-Force`, and `-PassThru`. |
| `Remove-CloudPCProvisioningPolicy` | Delete a provisioning policy by ID or pipeline object. Supports `-WhatIf`, `-Confirm`, `-Force`, and `-PassThru`. Graph cannot delete policies that are still in use. |
| `Reset-CloudPCLocalAdminPassword` | Rotate the local admin password for one or more Cloud PCs through the Intune managed device action. Accepts Cloud PC objects, exact names, Cloud PC IDs, or managed device IDs. |
| `Restart-CloudPC` | Reboot one or more Cloud PCs via Graph. Pipeline-friendly, `SupportsShouldProcess` (defaults to `ConfirmImpact='High'`), `-Force` to skip the prompt, `-PassThru` for a result object. |
| `Start-CloudPC` | Power on one or more Cloud PCs via Graph beta. Accepts Cloud PC objects, exact names, or IDs. Pipeline-friendly, supports `-WhatIf`, `-Force`, and `-PassThru`. |
| `Sync-CloudPC` | Sync one or more Cloud PCs through the Intune managed device `syncDevice` action. Accepts Cloud PC objects, exact names, Cloud PC IDs, or managed device IDs. |

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

# Export a provisioning policy to reusable JSON
Export-CloudPCProvisioningPolicy -Id '<policy-id>' -Path .\policy-export.json

# Preview creating a copy from the export
New-CloudPCProvisioningPolicy -Path .\policy-export.json -DisplayName 'Copied Policy' -WhatIf

# Create the copy and recreate exported assignment targets
New-CloudPCProvisioningPolicy -Path .\policy-export.json -DisplayName 'Copied Policy' -Assign -Force

# Copy a Flex Shared policy with a lower reserved Cloud PC allotment
New-CloudPCProvisioningPolicy -Path .\policy-export.json -DisplayName 'Copied Flex Shared Policy' -RegionName eastus2 -AllotmentLicensesCount 1 -Assign -Force

# Delete a copied provisioning policy
Remove-CloudPCProvisioningPolicy -Id '<policy-id>' -WhatIf
Remove-CloudPCProvisioningPolicy -Id '<policy-id>' -Force -PassThru

# List maintenance windows and assigned groups
Get-CloudPCMaintenanceWindow -IncludeAssignments |
    Format-Table DisplayName,ScheduleSummary,AssignedGroupNames

# Create a maintenance window and assign it to a group
New-CloudPCMaintenanceWindow `
    -DisplayName 'Off-Hours Resize Window' `
    -WeekdayStartTime '01:00' `
    -WeekdayEndTime '05:00' `
    -GroupId '<group-id>' `
    -Force |
    Format-Table DisplayName,Status,AssignmentStatus,AssignmentsApplied

# Remove a maintenance window by exact display name, clearing assignments first
Remove-CloudPCMaintenanceWindow -DisplayName 'Off-Hours Resize Window' -WhatIf

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

# Power on a Cloud PC by exact name or ID
Start-CloudPC -CloudPC 'CPC-brad-U2O0S' -Force -PassThru
Start-CloudPC -Id '<cloud-pc-id>' -Force -PassThru

# Sync a Cloud PC through the Intune managed device action
Sync-CloudPC -CloudPC 'CPC-brad-U2O0S' -Force -PassThru
Sync-CloudPC -ManagedDeviceId '<managed-device-id>' -Force -PassThru

# Rotate a Cloud PC local admin password through the Intune managed device action
Reset-CloudPCLocalAdminPassword -CloudPC 'CPC-brad-U2O0S' -Force -PassThru
Reset-CloudPCLocalAdminPassword -ManagedDeviceId '<managed-device-id>' -Force -PassThru

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
