---
id: get-cloudpcorganizationsetting
title: Get-CloudPCOrganizationSetting
description: "Returns Windows 365 Cloud PC organization settings."
---

# Get-CloudPCOrganizationSetting

Returns Windows 365 Cloud PC organization settings.

## Description

Calls the Microsoft Graph beta
https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/organizationSettings
endpoint and returns the tenant-wide Cloud PC organization settings.

A tenant has one cloudPcOrganizationSettings object. These settings include
default operating system version, default user account type, Microsoft
Endpoint Manager auto-enrollment, single sign-on, and Windows settings.

## Syntax

```powershell

Get-CloudPCOrganizationSetting [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| None |  |  |  | This command has no custom parameters. |

## Output

```plaintext
Id                   : 00000000-0000-0000-0000-000000000000
OsVersion            : windows11
UserAccountType      : standardUser
MEMAutoEnrollEnabled : True
SingleSignOnEnabled  : True
WindowsLanguage      : en-US
WindowsSettings      : @{language=en-US}
```

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/organizationSettings
```

## Example 1

```powershell
Get-CloudPCOrganizationSetting
```

## Example 2

```powershell
Get-CloudPCOrganizationSetting |
Select-Object OsVersion,UserAccountType,SingleSignOnEnabled,WindowsLanguage
```


## Source

[View Get-CloudPCOrganizationSetting.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Get-CloudPCOrganizationSetting.ps1)
