---
id: get-cloudpcbyprovisioningpolicy
title: Get-CloudPCByProvisioningPolicy
description: "Groups Cloud PCs under their provisioning policies and returns one row per policy."
---

# Get-CloudPCByProvisioningPolicy

Groups Cloud PCs under their provisioning policies and returns one row per policy.

## Description

Fetches Cloud PCs with Get-CloudPC and groups them by ProvisioningPolicyId, returning
one PSCustomObject per policy (PSTypeName = 'WindowsCloudPC.ProvisioningPolicyCloudPCs')
with a CloudPCCount and a CloudPCs array of the matching Get-CloudPC objects.

Useful for answering "how many Cloud PCs are on each policy" and "which Cloud PCs
belong to which policy" without leaving stale/null fields on the policy object itself.

Empty policies (policies with zero Cloud PCs provisioned) are included with
CloudPCCount = 0 and CloudPCs = @() so you can spot drift.

## Syntax

```powershell

Get-CloudPCByProvisioningPolicy [[-ProvisioningPolicyId] <string>] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `ProvisioningPolicyId` | `String` | No | `Id` | Optional: scope the result to a single policy. Accepts pipeline input by property<br />name from Get-CloudPCProvisioningPolicy. |

## Graph endpoints

Endpoint details are described in the source and examples.

## Example 1

```powershell
Get-CloudPCByProvisioningPolicy | Format-Table DisplayName,ProvisioningType,CloudPCCount
```

## Example 2

```powershell
Get-CloudPCByProvisioningPolicy |
Select-Object DisplayName -ExpandProperty CloudPCs |
Format-Table DisplayName,Name,ProvisioningStatus
```

## Example 3

```powershell
Get-CloudPCProvisioningPolicy -Id 8e8a545f-6168-4472-9466-9f05520a5eb3 |
Get-CloudPCByProvisioningPolicy
```


## Source

[View Get-CloudPCByProvisioningPolicy.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Get-CloudPCByProvisioningPolicy.ps1)
