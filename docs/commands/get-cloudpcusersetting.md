---
id: get-cloudpcusersetting
title: Get-CloudPCUserSetting
description: "Returns Windows 365 Cloud PC user settings."
---

# Get-CloudPCUserSetting

Returns Windows 365 Cloud PC user settings.

## Description

Calls the Microsoft Graph beta /deviceManagement/virtualEndpoint/userSettings
endpoint and returns normalized WindowsCloudPC.UserSetting objects.

By default, the cmdlet lists every user setting. Pass -Id to retrieve a
single user setting. Pass -IncludeAssignments to expand group assignments.

## Syntax

```powershell

Get-CloudPCUserSetting [[-Id] <string>] [-IncludeAssignments] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `Id` | `String` | No | `UserSettingId` | Optional user setting ID. When provided, the cmdlet retrieves only that<br />user setting. |
| `IncludeAssignments` | `SwitchParameter` | No |  | Includes assignment relationships by adding $expand=assignments. |

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/userSettings/
/beta/deviceManagement/virtualEndpoint/userSettings?
```

## Example 1

```powershell
Get-CloudPCUserSetting | Format-Table DisplayName,ResetEnabled,UserRestoreEnabled
```

Lists Cloud PC user settings with reset and restore status.

## Example 2

```powershell
Get-CloudPCUserSetting -Id '26494f36-064f-42e8-befd-fde474840402'
```

Gets one Cloud PC user setting by ID.

## Example 3

```powershell
Get-CloudPCUserSetting -IncludeAssignments |
Select-Object DisplayName,Assignments
```

Lists Cloud PC user settings and expands assignment relationships.


## Source

[View Get-CloudPCUserSetting.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Get-CloudPCUserSetting.ps1)
