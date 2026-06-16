---
id: reset-cloudpclocaladminpassword
title: Reset-CloudPCLocalAdminPassword
description: "Rotates the local admin password for one or more Windows 365 Cloud PCs."
---

# Reset-CloudPCLocalAdminPassword

Rotates the local admin password for one or more Windows 365 Cloud PCs.

## Description

Issues POST /deviceManagement/managedDevices('&#123;managedDeviceId&#125;')/rotateLocalAdminPassword
against Microsoft Graph beta, which initiates a manual local admin password rotation on
the underlying Intune managed device.

The cmdlet accepts Cloud PC objects from Get-CloudPC, exact Cloud PC names, Cloud PC IDs,
or managed device IDs. Use -ManagedDeviceId when you already have the Intune managedDevice ID.
It supports -WhatIf / -Confirm and defaults to ConfirmImpact = 'High'. Use -Force to suppress
the confirmation prompt in automation.

Requires the DeviceManagementManagedDevices.PrivilegedOperations.All scope; the cmdlet
automatically re-authenticates via Connect-CloudPC if the current Graph session does not
already have it.

## Syntax

```powershell

Reset-CloudPCLocalAdminPassword -CloudPC <Object> [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

Reset-CloudPCLocalAdminPassword -Id <string> [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

Reset-CloudPCLocalAdminPassword -ManagedDeviceId <string> [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `CloudPC` | `Object` | Yes |  | A WindowsCloudPC.CloudPC object (as returned by Get-CloudPC), or an exact Cloud PC name,<br />Cloud PC ID, or managed device ID. Accepts pipeline input. |
| `Force` | `SwitchParameter` | No |  | Suppress the confirmation prompt. Equivalent to -Confirm:$false. |
| `Id` | `String` | Yes | `CloudPcId` | The Cloud PC ID (GUID) when you do not have a CloudPC object handy. |
| `ManagedDeviceId` | `String` | Yes | `IntuneManagedDeviceId` | The Intune managedDevice ID to rotate the local admin password for directly. |
| `PassThru` | `SwitchParameter` | No |  | Emit a WindowsCloudPC.LocalAdminPasswordRotationResult object describing the outcome of each request.<br />By default the cmdlet is silent on success. |

## Graph endpoints

```text
/beta/deviceManagement/managedDevices('{managedDeviceId}')/rotateLocalAdminPassword
```

## Example 1

```powershell
Reset-CloudPCLocalAdminPassword -CloudPC 'CPC-brad-U2O0S' -Force -PassThru
```

Resolves a Cloud PC by exact name and rotates the local admin password for the underlying managed device.

## Example 2

```powershell
Reset-CloudPCLocalAdminPassword -Id 'f55ba1ae-4d31-4b41-a19f-5ca6fd5d8ffe' -Force -PassThru
```

Resolves a Cloud PC by ID, then rotates the local admin password for its Intune managed device.

## Example 3

```powershell
Reset-CloudPCLocalAdminPassword -ManagedDeviceId 'bbfae1fc-af9b-4621-9477-454ee0afe22b' -Force -PassThru
```

Sends the rotation request directly to an Intune managedDevice ID.


## Source

[View Reset-CloudPCLocalAdminPassword.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Reset-CloudPCLocalAdminPassword.ps1)
