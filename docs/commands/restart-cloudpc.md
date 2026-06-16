---
id: restart-cloudpc
title: Restart-CloudPC
description: "Reboots one or more Windows 365 Cloud PCs."
---

# Restart-CloudPC

Reboots one or more Windows 365 Cloud PCs.

## Description

Issues POST /deviceManagement/virtualEndpoint/cloudPCs/&#123;id&#125;/reboot against Microsoft Graph,
which is an asynchronous operation: Graph returns 204 No Content immediately and the actual
reboot happens in the background.

Because rebooting is destructive, this cmdlet supports -WhatIf / -Confirm and defaults to
ConfirmImpact = 'High'. Use -Force to suppress the confirmation prompt in automation.

Requires the CloudPC.ReadWrite.All scope; the cmdlet automatically re-authenticates via
Connect-CloudPC if the current Graph session does not already have it.

## Syntax

```powershell

Restart-CloudPC -CloudPC <CloudPC> [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

Restart-CloudPC -Id <string> [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `CloudPC` | `Object` | Yes |  | A WindowsCloudPC.CloudPC object (as returned by Get-CloudPC). Accepts pipeline input. |
| `Force` | `SwitchParameter` | No |  | Suppress the confirmation prompt. Equivalent to -Confirm:$false. |
| `Id` | `String` | Yes | `CloudPcId` | The Cloud PC ID (GUID) when you do not have a CloudPC object handy. |
| `PassThru` | `SwitchParameter` | No |  | Emit a WindowsCloudPC.RestartResult object describing the outcome of each reboot request.<br />By default the cmdlet is silent on success (mirrors Restart-Computer behavior). |

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/cloudPCs/{id}/reboot
```

## Example 1

```powershell
Get-CloudPC -Type Dedicated | Restart-CloudPC -Force
```

Reboots every dedicated Cloud PC in the tenant without prompting.

## Example 2

```powershell
Restart-CloudPC -Id '95194d88-cec5-4b65-af62-26dbd1814364' -PassThru
```

Reboots a single Cloud PC by ID, prompts for confirmation, and emits the request result.

## Example 3

```powershell
Get-CloudPC | Where-Object Name -like 'CFD-brad-*' | Restart-CloudPC -WhatIf
```

Previews which Cloud PCs would be rebooted without sending the requests.


## Source

[View Restart-CloudPC.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Restart-CloudPC.ps1)
