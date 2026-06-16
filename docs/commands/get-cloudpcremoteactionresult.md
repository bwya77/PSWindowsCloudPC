---
id: get-cloudpcremoteactionresult
title: Get-CloudPCRemoteActionResult
description: "Returns the recent remote-action history (restart, reprovision, restore, etc.) for a Cloud PC."
---

# Get-CloudPCRemoteActionResult

Returns the recent remote-action history (restart, reprovision, restore, etc.) for a Cloud PC.

## Description

Calls /beta/deviceManagement/virtualEndpoint/cloudPCs/&#123;id&#125;/retrieveCloudPCRemoteActionResults
which returns the collection of cloudPcRemoteActionResult entries Graph has on file for the
Cloud PC — typically the most recent occurrence of each action type with timing and status.

Use this immediately after a Restart-CloudPC / reprovision / restore to confirm that the
action was accepted and to watch ActionState transition from 'pending' to 'done' (or 'failed').

Emits one WindowsCloudPC.RemoteActionResult object per (CloudPC, action) pair, sorted by
StartDateTime descending so the most recent action is first.

## Syntax

```powershell

Get-CloudPCRemoteActionResult -CloudPC <CloudPC> [<CommonParameters>]

Get-CloudPCRemoteActionResult -Id <string> [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `CloudPC` | `Object` | Yes |  | A WindowsCloudPC.CloudPC object (as returned by Get-CloudPC). Accepts pipeline input. |
| `Id` | `String` | Yes | `CloudPcId` | The Cloud PC ID (GUID) when you do not have a CloudPC object handy. |

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/cloudPCs/{id}/retrieveCloudPCRemoteActionResults
```

## Example 1

```powershell
Get-CloudPCRemoteActionResult -Id '95194d88-cec5-4b65-af62-26dbd1814364'
```

Lists the recent remote-action history for a single Cloud PC.

## Example 2

```powershell
Get-CloudPC | Get-CloudPCRemoteActionResult | Format-Table CloudPcName,ActionName,ActionState,StartDateTime
```

Tenant-wide snapshot of the most recent action against each Cloud PC.

## Example 3

```powershell
$pc = Get-CloudPC | Where-Object Name -eq 'CFD-brad-TUFL7'
$pc | Restart-CloudPC -Force
$pc | Get-CloudPCRemoteActionResult | Where-Object ActionName -eq 'Restart'
```

Reboots a Cloud PC, then immediately queries its action history to confirm the request
landed (you'll see ActionState 'pending', transitioning to 'done').


## Source

[View Get-CloudPCRemoteActionResult.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Get-CloudPCRemoteActionResult.ps1)
