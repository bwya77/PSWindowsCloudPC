---
id: sync-cloudpc
title: Sync-CloudPC
description: "Syncs one or more Windows 365 Cloud PCs through the Intune managed device action."
---

# Sync-CloudPC

Syncs one or more Windows 365 Cloud PCs through the Intune managed device action.

## Description

Issues POST /deviceManagement/managedDevices/&#123;managedDeviceId&#125;/syncDevice against Microsoft Graph beta,
which asks Intune to check in the underlying managed device for a Cloud PC.

The cmdlet accepts Cloud PC objects from Get-CloudPC, exact Cloud PC names, Cloud PC IDs,
or managed device IDs. Use -ManagedDeviceId when you already have the Intune managedDevice ID.
It supports -WhatIf / -Confirm and defaults to ConfirmImpact = 'Medium'. Use -Force to suppress
the confirmation prompt in automation.

Requires the DeviceManagementManagedDevices.PrivilegedOperations.All scope; the cmdlet
automatically re-authenticates via Connect-CloudPC if the current Graph session does not
already have it.

## Syntax

```powershell

Sync-CloudPC -CloudPC <Object> [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

Sync-CloudPC -Id <string> [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

Sync-CloudPC -ManagedDeviceId <string> [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `CloudPC` | `Object` | Yes |  | A WindowsCloudPC.CloudPC object (as returned by Get-CloudPC), or an exact Cloud PC name,<br />Cloud PC ID, or managed device ID. Accepts pipeline input. |
| `Force` | `SwitchParameter` | No |  | Suppress the confirmation prompt. Equivalent to -Confirm:$false. |
| `Id` | `String` | Yes | `CloudPcId` | The Cloud PC ID (GUID) when you do not have a CloudPC object handy. |
| `ManagedDeviceId` | `String` | Yes | `IntuneManagedDeviceId` | The Intune managedDevice ID to sync directly. |
| `PassThru` | `SwitchParameter` | No |  | Emit a WindowsCloudPC.SyncResult object describing the outcome of each sync request.<br />By default the cmdlet is silent on success. |

## Graph endpoints

```text
/beta/deviceManagement/managedDevices/{managedDeviceId}/syncDevice
```

## Example 1

```powershell
Sync-CloudPC -CloudPC 'CPC-brad-U2O0S' -Force -PassThru
```

Resolves a Cloud PC by exact name and sends the sync request to the underlying managed device.

## Example 2

```powershell
Sync-CloudPC -Id 'f55ba1ae-4d31-4b41-a19f-5ca6fd5d8ffe' -Force -PassThru
```

Resolves a Cloud PC by ID, then syncs its Intune managed device.

## Example 3

```powershell
Sync-CloudPC -ManagedDeviceId 'a11da134-b0bf-4964-9887-c0034a5cbf43' -Force -PassThru
```

Sends the sync request directly to an Intune managedDevice ID.


## Source

[View Sync-CloudPC.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Sync-CloudPC.ps1)
