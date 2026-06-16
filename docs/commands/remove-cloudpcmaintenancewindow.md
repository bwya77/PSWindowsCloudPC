---
id: remove-cloudpcmaintenancewindow
title: Remove-CloudPCMaintenanceWindow
description: "Deletes a Windows 365 Cloud PC maintenance window."
---

# Remove-CloudPCMaintenanceWindow

Deletes a Windows 365 Cloud PC maintenance window.

## Description

Clears assignments, then deletes a Cloud PC maintenance window by calling Microsoft Graph beta:
POST /deviceManagement/virtualEndpoint/maintenanceWindows/&#123;id&#125;/assign
DELETE /deviceManagement/virtualEndpoint/maintenanceWindows/&#123;id&#125;.

Targets can be a maintenance window ID, exact display name, or a
WindowsCloudPC.MaintenanceWindow object from Get-CloudPCMaintenanceWindow.

## Syntax

```powershell

Remove-CloudPCMaintenanceWindow -MaintenanceWindow <MaintenanceWindow> [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

Remove-CloudPCMaintenanceWindow -Id <string> [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

Remove-CloudPCMaintenanceWindow -DisplayName <string> [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `DisplayName` | `String` | Yes | `Name` | Exact display name of the maintenance window to delete. Alias: Name. |
| `Force` | `SwitchParameter` | No |  | Suppress the confirmation prompt. Equivalent to -Confirm:$false. |
| `Id` | `String` | Yes | `MaintenanceWindowId` | The maintenance window ID. |
| `MaintenanceWindow` | `Object` | Yes |  | A WindowsCloudPC.MaintenanceWindow object returned by Get-CloudPCMaintenanceWindow. |
| `PassThru` | `SwitchParameter` | No |  | Emit a WindowsCloudPC.MaintenanceWindowRemoveResult object describing the outcome.<br />By default the cmdlet is silent on success. |

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/maintenanceWindows/{id}/assign
/beta/deviceManagement/virtualEndpoint/maintenanceWindows/{id}
```

## Example 1

```powershell
Remove-CloudPCMaintenanceWindow -DisplayName 'Off-Hours Window' -WhatIf
```

Previews deleting a maintenance window by exact display name.

## Example 2

```powershell
Get-CloudPCMaintenanceWindow -DisplayName 'Off-Hours Window' |
Remove-CloudPCMaintenanceWindow -Force -PassThru
```

Deletes a maintenance window from the pipeline and emits the delete result.


## Source

[View Remove-CloudPCMaintenanceWindow.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Remove-CloudPCMaintenanceWindow.ps1)
