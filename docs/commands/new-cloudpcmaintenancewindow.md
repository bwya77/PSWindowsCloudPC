---
id: new-cloudpcmaintenancewindow
title: New-CloudPCMaintenanceWindow
description: "Creates a Windows 365 Cloud PC maintenance window."
---

# New-CloudPCMaintenanceWindow

Creates a Windows 365 Cloud PC maintenance window.

## Description

Creates a Cloud PC maintenance window by calling Microsoft Graph beta:
POST /deviceManagement/virtualEndpoint/maintenanceWindows.

Use the weekday and weekend parameters for the common Intune portal model,
or pass one or more schedule objects with -Schedule for newer Graph schedule
types. Each schedule must be at least two hours long.

Pass -GroupId to assign the created maintenance window to Microsoft Entra
groups after creation.

## Syntax

```powershell

New-CloudPCMaintenanceWindow -DisplayName <string> -WeekdayStartTime <string> -WeekdayEndTime <string> [-Description <string>] [-NotificationLeadTimeInMinutes <int>] [-WeekendStartTime <string>] [-WeekendEndTime <string>] [-GroupId <string[]>] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]

New-CloudPCMaintenanceWindow -DisplayName <string> -Schedule <Object[]> [-Description <string>] [-NotificationLeadTimeInMinutes <int>] [-GroupId <string[]>] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `Description` | `String` | No |  | Optional description. |
| `DisplayName` | `String` | Yes |  | Display name for the maintenance window. |
| `Force` | `SwitchParameter` | No |  | Suppress confirmation prompts. Equivalent to -Confirm:$false. |
| `GroupId` | `String[]` | No |  | Microsoft Entra group IDs to assign after the maintenance window is created. |
| `NotificationLeadTimeInMinutes` | `Int32` | No |  | Number of minutes before the maintenance window opens that users are notified.<br />Defaults to 60. |
| `Schedule` | `Object[]` | Yes |  | One or more hashtables or objects with scheduleType, startTime, and endTime.<br />Times may be HH:mm or Graph time-of-day values such as 01:00:00.0000000. |
| `WeekdayEndTime` | `String` | Yes |  | End time for the weekday schedule in HH:mm format. |
| `WeekdayStartTime` | `String` | Yes |  | Start time for the weekday schedule in HH:mm format. |
| `WeekendEndTime` | `String` | No |  | Optional end time for the weekend schedule in HH:mm format.<br />If omitted, the weekday end time is used for the weekend schedule. |
| `WeekendStartTime` | `String` | No |  | Optional start time for the weekend schedule in HH:mm format.<br />If omitted, the weekday start time is used for the weekend schedule. |

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/maintenanceWindows
/beta/deviceManagement/virtualEndpoint/maintenanceWindows/{id}/assign
```

## Example 1

```powershell
New-CloudPCMaintenanceWindow -DisplayName 'Off-Hours Window' -WeekdayStartTime '01:00' -WeekdayEndTime '05:00' -Force
```

Creates a maintenance window with matching weekday and weekend schedules.

## Example 2

```powershell
New-CloudPCMaintenanceWindow -DisplayName 'Resize Window' -WeekdayStartTime '01:00' -WeekdayEndTime '05:00' -GroupId '<group-id>' -Force
```

Creates a maintenance window and assigns it to a Microsoft Entra group.


## Source

[View New-CloudPCMaintenanceWindow.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/New-CloudPCMaintenanceWindow.ps1)
