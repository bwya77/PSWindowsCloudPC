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

## Output

```plaintext
CloudPcId     : 95194d88-cec5-4b65-af62-26dbd1814364
CloudPcName   : CFD-brad-V46GR
ActivityId    : 00000000-0000-0000-0000-000000000000
EventDateTime : 5/20/2026 8:51:59 PM
EventType     : deviceHealthCheck
EventName     : Health Check
EventResult   : success
Message       :
Raw           : {[eventDateTime, 5/21/2026 1:51:59 AM], [activityId, 00000000-0000-0000-0000-000000000000], [message,
                ], [eventType, deviceHealthCheck]...}

CloudPcId     : 95194d88-cec5-4b65-af62-26dbd1814364
CloudPcName   : CFD-brad-V46GR
ActivityId    : 8f0e7939-f7db-4f0b-abdc-c27971140000
EventDateTime : 6/17/2026 1:31:45 PM
EventType     : userConnection
EventName     : Connection Started
EventResult   : success
Message       :
Raw           : {[eventDateTime, 6/17/2026 6:31:45 PM], [activityId, 8f0e7939-f7db-4f0b-abdc-c27971140000], [message,
                ], [eventType, userConnection]...}
```

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
