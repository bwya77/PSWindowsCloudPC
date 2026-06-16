---
id: get-cloudpcsettingprofile
title: Get-CloudPCSettingProfile
description: "Returns Windows 365 Cloud PC setting profiles."
---

# Get-CloudPCSettingProfile

Returns Windows 365 Cloud PC setting profiles.

## Description

Calls the Microsoft Graph beta /deviceManagement/virtualEndpoint/settingProfiles
endpoint and returns normalized WindowsCloudPC.SettingProfile objects.

By default, the cmdlet lists setting profiles. Pass -Id to retrieve a
single setting profile. Pass -IncludeDetails to expand assignments and
settings, including object and list setting children.

## Syntax

```powershell

Get-CloudPCSettingProfile [[-Id] <string>] [-IncludeDetails] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `Id` | `String` | No | `SettingProfileId`, `ProfileId` | Optional setting profile ID. When provided, the cmdlet retrieves only<br />that setting profile. |
| `IncludeDetails` | `SwitchParameter` | No |  | Expands assignments and settings. Settings expand children for<br />microsoft.graph.cloudPcObjectSetting and microsoft.graph.cloudPcListSetting. |

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/settingProfiles/
/beta/deviceManagement/virtualEndpoint/settingProfiles
```

## Example 1

```powershell
Get-CloudPCSettingProfile | Format-Table DisplayName,ProfileType,TemplateId,IsAssigned
```

Lists Cloud PC setting profiles.

## Example 2

```powershell
Get-CloudPCSettingProfile -Id '34fe1094-bf33-43dd-8bfc-92413dc624cc' -IncludeDetails
```

Gets one Cloud PC setting profile with assignments and settings expanded.

## Example 3

```powershell
Get-CloudPCSettingProfile -IncludeDetails |
Select-Object DisplayName,Assignments,Settings
```

Lists Cloud PC setting profiles with assignments and settings expanded.


## Source

[View Get-CloudPCSettingProfile.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Get-CloudPCSettingProfile.ps1)
