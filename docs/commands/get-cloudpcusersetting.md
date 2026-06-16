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

## Output

```plaintext
Id                                     : 00000000-0000-0000-0000-000000000000
DisplayName                            : User Reset and Restore Settings
SelfServiceEnabled                     : False
LocalAdminEnabled                      : False
ResetEnabled                           : True
RestorePointFrequencyInHours           : 12
RestorePointFrequencyType              : twelveHours
UserRestoreEnabled                     : True
CrossRegionDisasterRecoveryEnabled     : False
MaintainCrossRegionRestorePointEnabled : True
DisasterRecoveryType                   : notConfigured
UserInitiatedDisasterRecoveryAllowed   : False
DisasterRecoveryNetworkSetting         :
RestartPromptsDisabled                 : False
ProvisioningSourceType                 :
CreatedDateTime                        : 6/15/2026 9:19:31 PM
LastModifiedDateTime                   : 6/15/2026 9:19:31 PM
RestorePointSetting                    : {[frequencyType, twelveHours], [frequencyInHours, 12], [userRestoreEnabled, True]}
CrossRegionDisasterRecoverySetting     : {[userInitiatedDisasterRecoveryAllowed, False], [maintainCrossRegionRestorePointEnabled, True],
                                         [disasterRecoveryType, notConfigured], [crossRegionDisasterRecoveryEnabled, False]…}
NotificationSetting                    : {[restartPromptsDisabled, False]}
Assignments                            :
Raw                                    : {[crossRegionDisasterRecoverySetting, System.Collections.Hashtable], [localAdminEnabled, False],
                                         [lastModifiedDateTime, 6/16/2026 2:19:31 AM], [resetEnabled, True]…}
```

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
