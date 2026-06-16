---
id: get-cloudpcsnapshot
title: Get-CloudPCSnapshot
description: "Returns snapshots for one or more Windows 365 Cloud PCs."
---

# Get-CloudPCSnapshot

Returns snapshots for one or more Windows 365 Cloud PCs.

## Description

Calls the Microsoft Graph beta /deviceManagement/virtualEndpoint/cloudPCs/&#123;id&#125;/retrieveSnapshots
endpoint and returns normalized WindowsCloudPC.Snapshot objects.

The cmdlet accepts Cloud PC objects from Get-CloudPC through the pipeline
or a Cloud PC ID through -Id. Use -All to retrieve every Cloud PC first
and return snapshots with friendly Cloud PC names.

## Syntax

```powershell

Get-CloudPCSnapshot -CloudPC <Object> [<CommonParameters>]

Get-CloudPCSnapshot -Id <string> [-ResolveName] [<CommonParameters>]

Get-CloudPCSnapshot -All [<CommonParameters>]

Get-CloudPCSnapshot -User <string> [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `All` | `SwitchParameter` | Yes |  | Gets all Cloud PCs with Get-CloudPC, then returns snapshots for each one<br />with CloudPcName populated from the Cloud PC object. |
| `CloudPC` | `Object` | Yes |  | A WindowsCloudPC.CloudPC object returned by Get-CloudPC, or a Cloud PC<br />friendly name. Accepts pipeline input. |
| `Id` | `String` | Yes | `CloudPcId` | The Cloud PC ID when you do not have a CloudPC object available. |
| `ResolveName` | `SwitchParameter` | No |  | Looks up the Cloud PC when using -Id so CloudPcName contains a friendly<br />managed device name or display name instead of the ID. |
| `User` | `String` | Yes | `UserPrincipalName`, `UPN` | Gets Cloud PCs for the specified user principal name, then returns<br />snapshots for each one with CloudPcName populated from the Cloud PC object. |

## Output

```plaintext
Id                   : CPC_00000000-0000-0000-0000-000000000000_00000000-0000-0000-0000-000000000000
SnapshotId           : CPC_00000000-0000-0000-0000-000000000000_00000000-0000-0000-0000-000000000000
CloudPcId            : 00000000-0000-0000-0000-000000000000
CloudPcName          : CPC-USER-01
Status               : ready
SnapshotType         : automatic
CreatedDateTime      : 6/13/2026 8:12:27 AM
LastRestoredDateTime :
ExpirationDateTime   :
HealthCheckStatus    :
Raw                  : {[healthCheckStatus, ], [createdDateTime, 6/13/2026 1:12:27 PM], [snapshotType, automatic], [lastRestoredDateTime,
                       ]…}

Id                   : CPC_00000000-0000-0000-0000-000000000000_00000000-0000-0000-0000-000000000000
SnapshotId           : CPC_00000000-0000-0000-0000-000000000000_00000000-0000-0000-0000-000000000000
CloudPcId            : 00000000-0000-0000-0000-000000000000
CloudPcName          : CPC-USER-01
Status               : ready
SnapshotType         : automatic
CreatedDateTime      : 6/12/2026 8:11:54 PM
LastRestoredDateTime :
ExpirationDateTime   :
HealthCheckStatus    :
Raw                  : {[healthCheckStatus, ], [createdDateTime, 6/13/2026 1:11:54 AM], [snapshotType, automatic], [lastRestoredDateTime,
                       ]…}
```

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/cloudPCs/
```

## Example 1

```powershell
Get-CloudPCSnapshot -Id '8ab4e59b-1866-4ce9-8bc8-92856e61edf4'
```

Lists snapshots for a single Cloud PC.

## Example 2

```powershell
Get-CloudPCSnapshot -Id '8ab4e59b-1866-4ce9-8bc8-92856e61edf4' -ResolveName |
Format-Table CloudPcName,Status,SnapshotType,CreatedDateTime
```

Lists snapshots and resolves the Cloud PC friendly name.

## Example 3

```powershell
Get-CloudPCSnapshot -CloudPC 'CFD-Vance-XS4KT'
```

Looks up a Cloud PC by friendly name and lists its snapshots.

## Example 4

```powershell
Get-CloudPCSnapshot -User 'user@contoso.com' |
Format-Table CloudPcName,Status,SnapshotType,CreatedDateTime
```

Lists snapshots for Cloud PCs assigned to a user.

## Example 5

```powershell
Get-CloudPCSnapshot -All | Format-Table CloudPcName,Status,SnapshotType,CreatedDateTime
```

Lists snapshots for every Cloud PC, including friendly Cloud PC names.

## Example 6

```powershell
Get-CloudPC | Get-CloudPCSnapshot | Format-Table CloudPcName,Status,SnapshotType,CreatedDateTime
```

Lists snapshots for every Cloud PC returned by Get-CloudPC.

## Example 7

```powershell
Get-CloudPC -UserPrincipalName 'user@contoso.com' |
Get-CloudPCSnapshot |
Sort-Object CreatedDateTime -Descending
```

Lists snapshots for a user's Cloud PCs.


## Source

[View Get-CloudPCSnapshot.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Get-CloudPCSnapshot.ps1)
