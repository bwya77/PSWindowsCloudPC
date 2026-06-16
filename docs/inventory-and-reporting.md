---
id: inventory-and-reporting
title: Inventory and reporting
description: Query Cloud PCs, policies, usage, launch detail, and remote action history.
---

# Inventory and reporting

Use the read commands to build a current picture of the Windows 365 estate before taking action. The module returns objects so you can filter, sort, export, or pipe them into other commands.

## Cloud PC inventory

```powershell
Get-CloudPC |
    Sort-Object Name |
    Format-Table Name,ProvisioningStatus,ProvisioningType,AssignedUserUpn
```

Filter by user or provisioning policy when you already know the scope.

```powershell
Get-CloudPC -UserPrincipalName user@contoso.com
Get-CloudPC -ProvisioningPolicyId '<policy-id>'
```

## Provisioning policies

`Get-CloudPCByProvisioningPolicy` groups Cloud PCs under their provisioning policy so you can see the shape of the fleet.

```powershell
Get-CloudPCByProvisioningPolicy |
    Format-Table DisplayName,ProvisioningType,CloudPCCount,AssignedGroupCount
```

Use `Get-CloudPCProvisioningPolicy` when you need policy details and assignment metadata.

```powershell
Get-CloudPCProvisioningPolicy |
    Select-Object DisplayName,Id,ProvisioningType,ImageDisplayName,ManagedBy
```

## Export and recreate provisioning policies

Export a provisioning policy to JSON when you want to back it up, review the create body, or create a copy.

```powershell
Export-CloudPCProvisioningPolicy -Id '<policy-id>' -Path .\policy-export.json
```

The export separates the create-safe policy body from assignment targets. Create can be previewed first:

```powershell
New-CloudPCProvisioningPolicy -Path .\policy-export.json `
    -DisplayName 'Copied Policy' `
    -WhatIf
```

Create the policy and recreate exported assignment targets:

```powershell
New-CloudPCProvisioningPolicy -Path .\policy-export.json `
    -DisplayName 'Copied Policy' `
    -Assign `
    -Force
```

For Flex Shared policies, the assignment reserves an allotment count. If the source policy reserves more Cloud PCs than the tenant has remaining, lower the assignment count while importing:

```powershell
New-CloudPCProvisioningPolicy -Path .\policy-export.json `
    -DisplayName 'Copied Flex Shared Policy' `
    -RegionName eastus2 `
    -AllotmentLicensesCount 1 `
    -Assign `
    -Force
```

Assignments are applied after the new policy is created because Microsoft Graph uses a separate `/assign` action.

## Delete provisioning policies

Delete copied or unused provisioning policies by ID or from the pipeline. Microsoft Graph cannot delete a policy that is still in use.

```powershell
Remove-CloudPCProvisioningPolicy -Id '<policy-id>' -WhatIf

Remove-CloudPCProvisioningPolicy -Id '<policy-id>' -Force -PassThru
```

Pipeline usage:

```powershell
Get-CloudPCProvisioningPolicy -Id '<policy-id>' |
    Remove-CloudPCProvisioningPolicy -Force -PassThru
```

## Usage reporting

`Get-CloudPCUsage` combines Cloud PC inventory with managed device state so you can see active and idle Cloud PCs.

```powershell
Get-CloudPCUsage |
    Sort-Object DaysSinceLastSignIn -Descending |
    Format-Table CloudPcName,AssignedUserUpn,UsageStatus,DaysSinceLastSignIn
```

Common follow-up filters:

```powershell
# Idle for at least 14 days
Get-CloudPCUsage | Where-Object DaysSinceLastSignIn -ge 14

# Currently unavailable or stale
Get-CloudPCUsage | Where-Object UsageStatus -ne 'InUse'
```

## Launch details

Use launch details when troubleshooting the user connection path for one or more Cloud PCs.

```powershell
Get-CloudPC |
    Get-CloudPCLaunchDetail |
    Format-Table CloudPcName,UserPrincipalName,State,LastLoginDateTime
```

The module uses the newer `retrieveCloudPcLaunchDetail` Graph action, not the deprecated `getCloudPcLaunchInfo` action.

## Remote action history

After restart, reprovision, restore, or snapshot-related actions, use remote action history to check what Graph reports for the device.

```powershell
Get-CloudPCRemoteActionResult -CloudPC '<cloud-pc-id>' |
    Sort-Object StartDateTime -Descending |
    Format-Table ActionName,ActionState,StartDateTime,LastUpdatedDateTime
```

## Export reports

```powershell
Get-CloudPCUsage |
    Select-Object CloudPcName,AssignedUserUpn,UsageStatus,DaysSinceLastSignIn,LastSignInDateTime |
    Export-Csv .\cloudpc-usage.csv -NoTypeInformation
```
