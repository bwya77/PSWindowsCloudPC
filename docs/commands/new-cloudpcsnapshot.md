---
id: new-cloudpcsnapshot
title: New-CloudPCSnapshot
description: "Creates restore point snapshots for one or more Windows 365 Cloud PCs."
---

# New-CloudPCSnapshot

Creates restore point snapshots for one or more Windows 365 Cloud PCs.

## Description

Calls the Microsoft Graph beta /deviceManagement/virtualEndpoint/cloudPCs/&#123;id&#125;/createSnapshot
action. Graph returns 204 No Content when the asynchronous snapshot request is accepted.

Targets can be a single Cloud PC object, a Cloud PC ID, a friendly Cloud PC name,
all Cloud PCs in the tenant, all Cloud PCs assigned to a user, or all Cloud PCs
associated with a provisioning policy.

The cmdlet emits one WindowsCloudPC.SnapshotRequestResult row per target so batch
runs show exactly which Cloud PCs were invoked.

## Syntax

```powershell

New-CloudPCSnapshot -CloudPC <Object> [-StorageAccountId <string>] [-AccessTier <string>] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]

New-CloudPCSnapshot -Id <string> [-StorageAccountId <string>] [-AccessTier <string>] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]

New-CloudPCSnapshot -All [-ExcludeCloudPC <string[]>] [-StorageAccountId <string>] [-AccessTier <string>] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]

New-CloudPCSnapshot -User <string> [-ExcludeCloudPC <string[]>] [-StorageAccountId <string>] [-AccessTier <string>] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]

New-CloudPCSnapshot -ProvisioningPolicyId <string> [-ExcludeCloudPC <string[]>] [-StorageAccountId <string>] [-AccessTier <string>] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `AccessTier` | `String` | No |  | Optional blob access tier: hot, cool, cold, archive, or unknownFutureValue. |
| `All` | `SwitchParameter` | Yes |  | Creates snapshots for every Cloud PC returned by Get-CloudPC. |
| `CloudPC` | `Object` | Yes |  | A WindowsCloudPC.CloudPC object returned by Get-CloudPC, or a Cloud PC friendly name.<br />Accepts pipeline input. |
| `ExcludeCloudPC` | `String[]` | No | `Exclude`, `ExcludeId`, `ExcludeName` | Cloud PCs to skip. Match values against Cloud PC Id, Name, ManagedDeviceId,<br />AadDeviceId, or AssignedUserUpn. |
| `Force` | `SwitchParameter` | No |  | Suppress confirmation prompts. Equivalent to -Confirm:$false. |
| `Id` | `String` | Yes | `CloudPcId` | The Cloud PC ID when you do not have a CloudPC object available. |
| `ProvisioningPolicyId` | `String` | Yes | `PolicyId` | Creates snapshots for Cloud PCs associated with a provisioning policy. |
| `StorageAccountId` | `String` | No |  | Optional storage account ID that receives the restore point. |
| `User` | `String` | Yes | `UserPrincipalName`, `UPN` | Creates snapshots for Cloud PCs returned by Get-CloudPC -UserPrincipalName. |

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/cloudPCs/{id}/createSnapshot
```

## Example 1

```powershell
New-CloudPCSnapshot -CloudPC 'CFD-Vance-XS4KT' -Force
```

Creates a snapshot for one Cloud PC by friendly name.

## Example 2

```powershell
New-CloudPCSnapshot -User 'user@contoso.com' -Force
```

Creates snapshots for every Cloud PC assigned to the user.

## Example 3

```powershell
New-CloudPCSnapshot -ProvisioningPolicyId '<policy-id>' -ExcludeCloudPC 'CPC-KEEP-01','user2@contoso.com' -Force
```

Creates snapshots for every Cloud PC in the provisioning policy except the excluded targets.

## Example 4

```powershell
New-CloudPCSnapshot -All -WhatIf
```

Shows every Cloud PC that would receive a snapshot without sending requests.


## Source

[View New-CloudPCSnapshot.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/New-CloudPCSnapshot.ps1)
