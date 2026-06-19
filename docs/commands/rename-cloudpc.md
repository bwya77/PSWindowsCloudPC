---
id: rename-cloudpc
title: Rename-CloudPC
description: "Renames a Windows 365 Cloud PC display name."
---

# Rename-CloudPC

Renames a Windows 365 Cloud PC display name.

## Description

Calls Microsoft Graph v1.0
https://graph.microsoft.com/v1.0/deviceManagement/virtualEndpoint/cloudPCs/&#123;id&#125;/rename
to update the Cloud PC displayName.

When ManagedDeviceName is specified, the cmdlet also calls Microsoft Graph beta
https://graph.microsoft.com/beta/deviceManagement/managedDevices/&#123;managedDeviceId&#125;/setDeviceName
to rename the linked Intune managed device.

This is an asynchronous service action. Graph returns 204 No Content
when the rename request is accepted. Use -WhatIf to preview the request.

Requires the CloudPC.ReadWrite.All scope. Managed device rename also
requires DeviceManagementManagedDevices.PrivilegedOperations.All. The
cmdlet automatically reauthenticates via Connect-CloudPC if the current
Graph session does not already have the required scopes.

## Syntax

```powershell

Rename-CloudPC -CloudPC <Object> -NewDisplayName <string> [-ManagedDeviceName <string>] [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

Rename-CloudPC -Id <string> -NewDisplayName <string> [-ManagedDeviceName <string>] [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `CloudPC` | `Object` | Yes |  | A WindowsCloudPC.CloudPC object returned by Get-CloudPC, or an exact<br />Cloud PC name, Cloud PC ID, managed device ID, Azure AD device ID, or<br />assigned user principal name. Accepts pipeline input. |
| `Force` | `SwitchParameter` | No |  | Suppress confirmation prompts. Equivalent to -Confirm:$false. |
| `Id` | `String` | Yes | `CloudPcId` | The Cloud PC ID when you do not have a CloudPC object available. |
| `ManagedDeviceName` | `String` | No | `DeviceName` | Optional new Intune managed device name. When provided, Rename-CloudPC also<br />calls the managedDevice setDeviceName action for the Cloud PC's linked<br />managed device. Alias: DeviceName. |
| `NewDisplayName` | `String` | Yes |  | The new Cloud PC display name. |
| `PassThru` | `SwitchParameter` | No |  | Emit a WindowsCloudPC.RenameResult object describing the request. |

## Output

```plaintext
CloudPcId                 : 00000000-0000-0000-0000-000000000000
CloudPcName               : CPC-USER-01
ManagedDeviceId           : 00000000-0000-0000-0000-000000000000
NewDisplayName            : Finance-CloudPC-01
NewManagedDeviceName      : Finance-CloudPC-01
Status                    : Accepted
ManagedDeviceRenameStatus : Accepted
RequestedAt               : 6/19/2026 2:15:00 PM
ErrorMessage              :
ManagedDeviceErrorMessage :
```

## Graph endpoints

```text
/v1.0/deviceManagement/virtualEndpoint/cloudPCs/{id}/rename
/beta/deviceManagement/managedDevices/{managedDeviceId}/setDeviceName
```

## Example 1

```powershell
Rename-CloudPC -CloudPC 'CPC-USER-01' -NewDisplayName 'Finance-CloudPC-01' -WhatIf
```

## Example 2

```powershell
Get-CloudPC -UserPrincipalName user@contoso.com |
Rename-CloudPC -NewDisplayName 'User-Primary-CloudPC' -Force -PassThru
```

## Example 3

```powershell
Rename-CloudPC -Id '<cloud-pc-id>' -NewDisplayName 'Cloud PC-HR' -PassThru
```

## Example 4

```powershell
Rename-CloudPC -CloudPC 'CPC-USER-01' -NewDisplayName 'Finance-CloudPC-01' -ManagedDeviceName 'Finance-CloudPC-01' -Force -PassThru
```


## Source

[View Rename-CloudPC.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Rename-CloudPC.ps1)
