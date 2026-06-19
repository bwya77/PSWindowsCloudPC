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

## Disk space reporting

`Get-CloudPCDiskSpace` joins Cloud PC inventory to the matching Intune managed device record and reports OS disk totals from Intune inventory. Use `LastSyncDateTime` to understand how fresh the storage data is.

```powershell
Get-CloudPCDiskSpace |
    Sort-Object PercentFree |
    Format-Table CloudPcName,AssignedUserUpn,FreeStorageGB,TotalStorageGB,PercentFree,LastSyncDateTime
```

Common low-space filter:

```powershell
Get-CloudPCDiskSpace |
    Where-Object PercentFree -lt 15 |
    Format-Table CloudPcName,AssignedUserUpn,FreeStorageGB,PercentFree,LastSyncDateTime
```

## Launch details

Use launch details when troubleshooting the user connection path for one or more Cloud PCs.

```powershell
Get-CloudPC |
    Get-CloudPCLaunchDetail |
    Format-Table CloudPcName,UserPrincipalName,State,LastLoginDateTime
```

The module uses the newer `retrieveCloudPcLaunchDetail` Graph action, not the deprecated `getCloudPcLaunchInfo` action.

## Graph Cloud PC report streams

`Get-CloudPCReport` retrieves Windows 365 Cloud PC report streams from Microsoft Graph beta and parses the downloaded `Schema` and `Values` file into typed PowerShell rows.

```powershell
$pc = Get-CloudPC | Select-Object -First 1
Get-CloudPCReport -ReportName remoteConnectionHistoricalReports -CloudPcId $pc.Id -Top 50 |
    Format-Table ManagedDeviceName,SignInDateTime,SignOutDateTime,UsageInHour
```

Use `-Select`, `-Filter`, `-Search`, `-GroupBy`, `-OrderBy`, `-Skip`, and `-Top` to pass Graph report query options when the target report action supports them. The command intentionally exposes only reports that returned successfully in live testing. Deprecated reports, tenant-state-dependent aliases that returned Graph 400s, and enum values without callable actions are excluded from `-ReportName`.

```powershell
Get-CloudPCReport -ReportName regionalConnectionQualityTrendReport -Top 50 |
    Format-Table GatewayRegionName,WeeklyAvgRoundTripTimeInMs,WeeklyAvgAvailableBandwidthInMbps
```

`realTimeRemoteConnectionStatus` uses the Graph report stream payload shape, but it is a GET function scoped to a Cloud PC ID. Omit `-CloudPcId` to query every Cloud PC in the tenant.

```powershell
Get-CloudPCReport -ReportName realTimeRemoteConnectionStatus |
    Format-Table ManagedDeviceName,SignInStatus,DaysSinceLastSignIn,LastActiveTime
```

For large tenants, the cmdlet honors Graph `Retry-After` responses for 429 throttling and retries transient 503/504 responses. You can also add a small delay between per-Cloud-PC calls to proactively pace the tenant-wide loop.

```powershell
Get-CloudPCReport -ReportName realTimeRemoteConnectionStatus -RequestDelayMilliseconds 100
```

Use `-OutputFilePath` to keep the raw Graph report file for audit or troubleshooting, or `-Raw` to inspect the parsed payload and schema directly.

Some Graph reports require scoped filters. Use `-CloudPcId` for `remoteConnectionHistoricalReports`, and use an `ActivityId` from that history when drilling into `rawRemoteConnectionReports`.

```powershell
$activity = Get-CloudPCReport -ReportName remoteConnectionHistoricalReports -CloudPcId $pc.Id -Top 1

Get-CloudPCReport -ReportName rawRemoteConnectionReports `
    -ActivityId $activity.ActivityId `
    -Select Timestamp,RoundTripTimeInMs,AvailableBandwidthInMBps
```

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
