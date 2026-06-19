---
id: restore-cloudpc
title: Restore-CloudPC
description: "Restores a Windows 365 Cloud PC from a restore point snapshot."
---

# Restore-CloudPC

Restores a Windows 365 Cloud PC from a restore point snapshot.

## Description

Calls Microsoft Graph v1.0
https://graph.microsoft.com/v1.0/deviceManagement/virtualEndpoint/cloudPCs/&#123;id&#125;/restore
to restore a Cloud PC from a snapshot ID.

This is a destructive asynchronous service action. Graph returns
204 No Content when the restore request is accepted. Use -WhatIf to
preview the request before restoring a device.

Requires the CloudPC.ReadWrite.All scope; the cmdlet automatically
reauthenticates via Connect-CloudPC if the current Graph session does
not already have it.

## Syntax

```powershell

Restore-CloudPC -CloudPC <Object> -SnapshotId <string> [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

Restore-CloudPC -Id <string> -SnapshotId <string> [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

Restore-CloudPC -Snapshot <Object> [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `CloudPC` | `Object` | Yes |  | A WindowsCloudPC.CloudPC object returned by Get-CloudPC, or an exact<br />Cloud PC name, Cloud PC ID, managed device ID, Azure AD device ID, or<br />assigned user principal name. Accepts pipeline input. |
| `Force` | `SwitchParameter` | No |  | Suppress confirmation prompts. Equivalent to -Confirm:$false. |
| `Id` | `String` | Yes | `CloudPcId` | The Cloud PC ID when you do not have a CloudPC object available. |
| `PassThru` | `SwitchParameter` | No |  | Emit a WindowsCloudPC.RestoreResult object describing the request. |
| `Snapshot` | `Object` | Yes |  | A WindowsCloudPC.Snapshot object returned by Get-CloudPCSnapshot.<br />The CloudPcId and SnapshotId properties are used for the restore request. |
| `SnapshotId` | `String` | Yes |  | The snapshot ID to restore from when the Cloud PC is supplied separately. |

## Output

```plaintext
CloudPcId    : 00000000-0000-0000-0000-000000000000
CloudPcName  : CPC-USER-01
SnapshotId   : A00009UV000_00000000-0000-0000-0000-000000000000
Status       : Accepted
RequestedAt  : 6/19/2026 2:15:00 PM
ErrorMessage :
```

## Graph endpoints

```text
/v1.0/deviceManagement/virtualEndpoint/cloudPCs/{id}/restore
```

## Example 1

```powershell
Get-CloudPCSnapshot -CloudPC 'CPC-USER-01' |
Select-Object -First 1 |
Restore-CloudPC -WhatIf
```

## Example 2

```powershell
Restore-CloudPC -CloudPC 'CPC-USER-01' -SnapshotId '<snapshot-id>' -Force -PassThru
```

## Example 3

```powershell
Restore-CloudPC -Id '<cloud-pc-id>' -SnapshotId '<snapshot-id>' -PassThru
```


## Source

[View Restore-CloudPC.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Restore-CloudPC.ps1)
