---
id: get-cloudpcmaintenancewindow
title: Get-CloudPCMaintenanceWindow
description: "Returns Windows 365 Cloud PC maintenance windows."
---

# Get-CloudPCMaintenanceWindow

Returns Windows 365 Cloud PC maintenance windows.

## Description

Wraps Microsoft Graph beta /deviceManagement/virtualEndpoint/maintenanceWindows
and returns normalized WindowsCloudPC.MaintenanceWindow objects.

Pass -IncludeAssignments to expand assigned Microsoft Entra groups and resolve
their display names.

## Syntax

```powershell

Get-CloudPCMaintenanceWindow [-DisplayName <string>] [-IncludeAssignments] [<CommonParameters>]

Get-CloudPCMaintenanceWindow [[-Id] <string>] [-IncludeAssignments] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `DisplayName` | `String` | No | `Name` | Optional exact display name filter. Alias: Name. |
| `Id` | `String` | No | `MaintenanceWindowId` | Optional maintenance window ID. Accepts pipeline input by property name. |
| `IncludeAssignments` | `SwitchParameter` | No |  | Expand assignment relationships and resolve assigned group display names. |

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/maintenanceWindows/{id}
/beta/deviceManagement/virtualEndpoint/maintenanceWindows?$expand=assignments
/beta/deviceManagement/virtualEndpoint/maintenanceWindows
```

## Example 1

```powershell
Get-CloudPCMaintenanceWindow | Format-Table DisplayName,ScheduleSummary
```

Lists Cloud PC maintenance windows and their schedule summary.

## Example 2

```powershell
Get-CloudPCMaintenanceWindow -DisplayName 'Off-Hours Window' -IncludeAssignments
```

Returns one maintenance window by exact display name and includes assigned groups.


## Source

[View Get-CloudPCMaintenanceWindow.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Get-CloudPCMaintenanceWindow.ps1)
