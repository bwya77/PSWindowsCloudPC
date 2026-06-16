---
id: remove-cloudpcprovisioningpolicy
title: Remove-CloudPCProvisioningPolicy
description: "Deletes a Windows 365 Cloud PC provisioning policy."
---

# Remove-CloudPCProvisioningPolicy

Deletes a Windows 365 Cloud PC provisioning policy.

## Description

Deletes a Cloud PC provisioning policy by calling Microsoft Graph beta:
DELETE /deviceManagement/virtualEndpoint/provisioningPolicies/&#123;id&#125;.

Microsoft Graph cannot delete a provisioning policy that is still in use.
This cmdlet supports -WhatIf / -Confirm and defaults to ConfirmImpact = 'High'.
Use -Force to suppress the confirmation prompt in automation.

Requires the CloudPC.ReadWrite.All scope; the cmdlet automatically
reauthenticates through Connect-CloudPC if the current Graph session does
not already have it.

## Syntax

```powershell

Remove-CloudPCProvisioningPolicy -Id <string> [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

Remove-CloudPCProvisioningPolicy -ProvisioningPolicy <ProvisioningPolicy> [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `Force` | `SwitchParameter` | No |  | Suppress the confirmation prompt. Equivalent to -Confirm:$false. |
| `Id` | `String` | Yes | `ProvisioningPolicyId` | The Cloud PC provisioning policy ID. |
| `PassThru` | `SwitchParameter` | No |  | Emit a WindowsCloudPC.ProvisioningPolicyRemoveResult object describing the outcome.<br />By default the cmdlet is silent on success. |
| `ProvisioningPolicy` | `Object` | Yes |  | A WindowsCloudPC.ProvisioningPolicy object returned by Get-CloudPCProvisioningPolicy. |

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/provisioningPolicies/{id}
```

## Example 1

```powershell
Remove-CloudPCProvisioningPolicy -Id '96e8ec2e-949c-40ca-a345-100a0035d0d1' -WhatIf
```

Previews deleting a provisioning policy by ID.

## Example 2

```powershell
Get-CloudPCProvisioningPolicy -Id '96e8ec2e-949c-40ca-a345-100a0035d0d1' |
Remove-CloudPCProvisioningPolicy -Force -PassThru
```

Deletes a provisioning policy from the pipeline and emits the delete result.


## Source

[View Remove-CloudPCProvisioningPolicy.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Remove-CloudPCProvisioningPolicy.ps1)
