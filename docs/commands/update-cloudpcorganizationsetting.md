---
id: update-cloudpcorganizationsetting
title: Update-CloudPCOrganizationSetting
description: "Updates Windows 365 Cloud PC organization settings."
---

# Update-CloudPCOrganizationSetting

Updates Windows 365 Cloud PC organization settings.

## Description

Calls Microsoft Graph beta
https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/organizationSettings
to update tenant-wide Cloud PC organization settings.

Only supplied parameters are sent in the PATCH body. Use -WhatIf to
preview changes before updating tenant defaults.

## Syntax

```powershell

Update-CloudPCOrganizationSetting [[-OsVersion] <string>] [[-UserAccountType] <string>] [[-EnableMEMAutoEnroll] <bool>] [[-EnableSingleSignOn] <bool>] [[-WindowsLanguage] <string>] [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `EnableMEMAutoEnroll` | `Boolean` | No |  | Whether new Cloud PCs should automatically enroll in Microsoft Endpoint Manager. |
| `EnableSingleSignOn` | `Boolean` | No |  | Whether new Cloud PCs support single sign-on. |
| `Force` | `SwitchParameter` | No |  | Suppress confirmation prompts. Equivalent to -Confirm:$false. |
| `OsVersion` | `String` | No |  | Default operating system version for new Cloud PCs: windows10 or windows11. |
| `PassThru` | `SwitchParameter` | No |  | Emit a WindowsCloudPC.OrganizationSettingUpdateResult object describing the request. |
| `UserAccountType` | `String` | No |  | Default user account type for new Cloud PCs: standardUser or administrator. |
| `WindowsLanguage` | `String` | No |  | Windows language to apply while creating Cloud PCs, such as en-US. |

## Output

```plaintext
Status       : Accepted
RequestedAt  : 6/19/2026 3:30:00 PM
Body         : {[@odata.type, #microsoft.graph.cloudPcOrganizationSettings], [osVersion, windows11], [userAccountType, standardUser]}
ErrorMessage :
```

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/organizationSettings
```

## Example 1

```powershell
Update-CloudPCOrganizationSetting -EnableSingleSignOn $true -WhatIf
```

## Example 2

```powershell
Update-CloudPCOrganizationSetting -OsVersion windows11 -UserAccountType standardUser -WindowsLanguage en-US -Force -PassThru
```


## Source

[View Update-CloudPCOrganizationSetting.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Update-CloudPCOrganizationSetting.ps1)
