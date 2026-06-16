---
id: invoke-cloudpcpolicyreprovision
title: Invoke-CloudPCPolicyReprovision
description: "Reprovisions Cloud PCs assigned to a provisioning policy."
---

# Invoke-CloudPCPolicyReprovision

Reprovisions Cloud PCs assigned to a provisioning policy.

## Description

Resolves the Cloud PCs associated with a provisioning policy, optionally removes
excluded Cloud PCs by name, ID, managed device ID, Azure AD device ID, or assigned
user UPN, then invokes Invoke-CloudPCReprovision for each remaining Cloud PC.

The cmdlet emits one WindowsCloudPC.PolicyReprovisionResult row per Cloud PC it
considered, including excluded rows. This makes the target list explicit before
you rely on the action results.

Because reprovisioning resets Cloud PCs, this cmdlet supports -WhatIf / -Confirm
and defaults to ConfirmImpact = 'High'. Use -Force to suppress confirmation prompts
in automation.

## Syntax

```powershell

Invoke-CloudPCPolicyReprovision [-ProvisioningPolicyId] <string> [-ExcludeCloudPC <string[]>] [-OsVersion <string>] [-UserAccountType <string>] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `ExcludeCloudPC` | `String[]` | No | `Exclude`, `ExcludeId`, `ExcludeName` | Cloud PCs to skip. Match values against Cloud PC Id, Name, ManagedDeviceId,<br />AadDeviceId, or AssignedUserUpn. Use this to run against the whole policy except<br />a small number of Cloud PCs. |
| `Force` | `SwitchParameter` | No |  | Suppress confirmation prompts. Equivalent to -Confirm:$false. |
| `OsVersion` | `String` | No |  | Optional operating system version for reprovisioned Cloud PCs: windows10 or windows11. |
| `ProvisioningPolicyId` | `String` | Yes | `Id` | The provisioning policy ID. Accepts pipeline input by property name from<br />Get-CloudPCProvisioningPolicy or Get-CloudPCByProvisioningPolicy. |
| `UserAccountType` | `String` | No |  | Optional account type for provisioned users: standardUser or administrator. |

## Graph endpoints

Endpoint details are described in the source and examples.

## Example 1

```powershell
Invoke-CloudPCPolicyReprovision -ProvisioningPolicyId '8e8a545f-6168-4472-9466-9f05520a5eb3' -WhatIf
```

Shows every Cloud PC in the policy that would be reprovisioned.

## Example 2

```powershell
Invoke-CloudPCPolicyReprovision -ProvisioningPolicyId '8e8a545f-6168-4472-9466-9f05520a5eb3' `
-ExcludeCloudPC 'CPC-KEEP-01','CPC-KEEP-02','cpc-id-3','user4@contoso.com' `
-OsVersion windows11 -UserAccountType standardUser -Force
```

Reprovisions every Cloud PC in the policy except the four specified Cloud PCs.


## Source

[View Invoke-CloudPCPolicyReprovision.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Invoke-CloudPCPolicyReprovision.ps1)
