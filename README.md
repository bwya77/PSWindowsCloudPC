# WindowsCloudPC

PowerShell module for managing and querying Windows 365 Cloud PCs via Microsoft Graph (beta).

## Status

Early scaffold. Read-only functions only.

## Requirements

- PowerShell 7+
- `Microsoft.Graph.Authentication` module
- Delegated Graph scopes (requested automatically by `Connect-CloudPC`):
  - `CloudPC.Read.All`
  - `DeviceManagementManagedDevices.Read.All`
  - `User.Read.All`

## Install (dev / local)

```powershell
# From the parent folder containing WindowsCloudPC\
Import-Module .\WindowsCloudPC -Force
```

## Functions

| Function | Purpose |
| --- | --- |
| `Connect-CloudPC` | Idempotent Graph sign-in with the right scopes. |
| `Get-CloudPC` | List Cloud PCs (filter by policy, user, or type). Returns `WindowsCloudPC.CloudPC` objects with `.Raw` preserved. |
| `Get-CloudPCUsage` | For each Cloud PC, return who is signed in and whether it is `inUse` / `available`. Handles shared (frontline) and dedicated. |

## Quick start

```powershell
Import-Module .\WindowsCloudPC -Force
Connect-CloudPC

# Everything in the tenant
Get-CloudPCUsage | Format-Table CloudPcName,ProvisioningType,UsageStatus,CurrentUserDisplayName,SessionStart

# One provisioning policy (e.g. Frontline Shared)
Get-CloudPCUsage -ProvisioningPolicyId 8e8a545f-6168-4472-9466-9f05520a5eb3

# Only available shared frontline PCs
Get-CloudPCUsage -Type Shared | Where-Object UsageStatus -eq 'available'

# Pipeline composition
Get-CloudPC -Type Dedicated | Get-CloudPCUsage | Export-Csv .\dedicated-usage.csv -NoTypeInformation
```

## Roadmap

- `Get-CloudPCProvisioningPolicy`
- `Get-CloudPCConnection` (connectivity health history)
- `Restart-CloudPC`, `Restore-CloudPC`, `Resize-CloudPC`, `Reprovision-CloudPC`
- `Get-CloudPCAuditEvent`
- Format file (`.format.ps1xml`) for default table views
- Pester tests
