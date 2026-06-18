---
id: get-cloudpcconnectivityhistory
title: Get-CloudPCConnectivityHistory
description: "Gets connectivity history for one or more Windows 365 Cloud PCs."
---

# Get-CloudPCConnectivityHistory

Gets connectivity history for one or more Windows 365 Cloud PCs.

## Description

Calls the Microsoft Graph beta
/deviceManagement/virtualEndpoint/cloudPCs/&#123;id&#125;/getCloudPcConnectivityHistory
endpoint and normalizes the returned cloudPcConnectivityEvent collection.

The cmdlet accepts Cloud PC IDs directly or WindowsCloudPC.CloudPC objects
from Get-CloudPC. It emits one WindowsCloudPC.CloudPCConnectivityEvent
object per returned event.

## Syntax

```powershell

Get-CloudPCConnectivityHistory -CloudPcId <string[]> [<CommonParameters>]

Get-CloudPCConnectivityHistory -CloudPC <CloudPC[]> [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `CloudPC` | `PSObject[]` | Yes |  | Cloud PC objects from Get-CloudPC. Pipeline input is supported. |
| `CloudPcId` | `String[]` | Yes |  | One or more Cloud PC IDs. |

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/cloudPCs/{id}/getCloudPcConnectivityHistory
```

## Example 1

```powershell
Get-CloudPCConnectivityHistory -CloudPcId 'f55ba1ae-4d31-4b41-a19f-5ca6fd5d8ffe'
```

## Example 2

```powershell
Get-CloudPC -Type Dedicated | Get-CloudPCConnectivityHistory |
Sort-Object EventDateTime -Descending |
Format-Table CloudPcName,EventDateTime,EventType,EventName,EventResult
```


## Source

[View Get-CloudPCConnectivityHistory.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Get-CloudPCConnectivityHistory.ps1)
