---
id: start-cloudpc
title: Start-CloudPC
description: "Powers on one or more Windows 365 Cloud PCs."
---

# Start-CloudPC

Powers on one or more Windows 365 Cloud PCs.

## Description

Issues POST /deviceManagement/virtualEndpoint/cloudPCs/&#123;id&#125;/powerOn against Microsoft Graph beta,
which is an asynchronous operation: Graph returns 204 No Content immediately and the actual
power-on action happens in the background.

The cmdlet accepts Cloud PC objects from Get-CloudPC, exact Cloud PC names, or Cloud PC IDs.
It supports -WhatIf / -Confirm and defaults to ConfirmImpact = 'High'. Use -Force to suppress
the confirmation prompt in automation.

Requires the CloudPC.ReadWrite.All scope; the cmdlet automatically re-authenticates via
Connect-CloudPC if the current Graph session does not already have it.

## Syntax

```powershell

Start-CloudPC -CloudPC <Object> [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

Start-CloudPC -Id <string> [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `CloudPC` | `Object` | Yes |  | A WindowsCloudPC.CloudPC object (as returned by Get-CloudPC), or a Cloud PC name or ID.<br />Accepts pipeline input. |
| `Force` | `SwitchParameter` | No |  | Suppress the confirmation prompt. Equivalent to -Confirm:$false. |
| `Id` | `String` | Yes | `CloudPcId` | The Cloud PC ID (GUID) when you do not have a CloudPC object handy. |
| `PassThru` | `SwitchParameter` | No |  | Emit a WindowsCloudPC.PowerOnResult object describing the outcome of each power-on request.<br />By default the cmdlet is silent on success. |

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/cloudPCs/{id}/powerOn
```

## Example 1

```powershell
Start-CloudPC -Id '8ab4e59b-1866-4ce9-8bc8-92856e61edf4' -Force -PassThru
```

Powers on a single Cloud PC by ID without prompting and emits the request result.

## Example 2

```powershell
Start-CloudPC -CloudPC 'CPC-brad-U2O0S' -Force
```

Resolves a Cloud PC by exact name and sends the power-on request.

## Example 3

```powershell
Get-CloudPC -Type Dedicated | Start-CloudPC -WhatIf
```

Previews which dedicated Cloud PCs would be powered on without sending requests.


## Source

[View Start-CloudPC.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Start-CloudPC.ps1)
