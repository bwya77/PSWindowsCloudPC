---
id: invoke-cloudpcreprovision
title: Invoke-CloudPCReprovision
description: "Reprovisions one or more Windows 365 Cloud PCs."
---

# Invoke-CloudPCReprovision

Reprovisions one or more Windows 365 Cloud PCs.

## Description

Issues POST /deviceManagement/virtualEndpoint/cloudPCs/&#123;id&#125;/reprovision against Microsoft Graph,
which is an asynchronous operation: Graph returns 204 No Content immediately and the actual
reprovisioning happens in the background.

Because reprovisioning resets the Cloud PC, this cmdlet supports -WhatIf / -Confirm and defaults
to ConfirmImpact = 'High'. Use -Force to suppress the confirmation prompt in automation.

Requires the CloudPC.ReadWrite.All scope; the cmdlet automatically re-authenticates via
Connect-CloudPC if the current Graph session does not already have it.

## Syntax

```powershell

Invoke-CloudPCReprovision -CloudPC <CloudPC> [-OsVersion <string>] [-UserAccountType <string>] [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

Invoke-CloudPCReprovision -Id <string> [-OsVersion <string>] [-UserAccountType <string>] [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `CloudPC` | `Object` | Yes |  | A WindowsCloudPC.CloudPC object (as returned by Get-CloudPC). Accepts pipeline input. |
| `Force` | `SwitchParameter` | No |  | Suppress the confirmation prompt. Equivalent to -Confirm:$false. |
| `Id` | `String` | Yes | `CloudPcId` | The Cloud PC ID (GUID) when you do not have a CloudPC object handy. |
| `OsVersion` | `String` | No |  | Optional operating system version for the reprovisioned Cloud PC: windows10 or windows11. |
| `PassThru` | `SwitchParameter` | No |  | Emit a WindowsCloudPC.ReprovisionResult object describing the outcome of each reprovision request.<br />By default the cmdlet is silent on success. |
| `UserAccountType` | `String` | No |  | Optional account type for the provisioned user: standardUser or administrator. |

## Graph endpoints

```text
/v1.0/deviceManagement/virtualEndpoint/cloudPCs/{id}/reprovision
```

## Example 1

```powershell
Get-CloudPC -Type Dedicated | Invoke-CloudPCReprovision -OsVersion windows11 -UserAccountType standardUser -Force
```

Reprovisions every dedicated Cloud PC in the tenant as Windows 11 with standard user rights.

## Example 2

```powershell
Invoke-CloudPCReprovision -Id '95194d88-cec5-4b65-af62-26dbd1814364' -UserAccountType administrator -PassThru
```

Reprovisions a single Cloud PC by ID, prompts for confirmation, and emits the request result.

## Example 3

```powershell
Get-CloudPC | Where-Object Name -like 'CFD-brad-*' | Invoke-CloudPCReprovision -WhatIf
```

Previews which Cloud PCs would be reprovisioned without sending the requests.


## Source

[View Invoke-CloudPCReprovision.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Invoke-CloudPCReprovision.ps1)
