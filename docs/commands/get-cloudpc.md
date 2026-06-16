---
id: get-cloudpc
title: Get-CloudPC
description: "Returns Windows 365 Cloud PCs in the tenant."
---

# Get-CloudPC

Returns Windows 365 Cloud PCs in the tenant.

## Description

Thin, fast wrapper over /beta/deviceManagement/virtualEndpoint/cloudPCs that returns
normalized PSCustomObjects (PSTypeName = 'WindowsCloudPC.CloudPC') suitable for piping
into Get-CloudPCUsage, Where-Object, Format-Table, etc. The raw Graph object is preserved
on the .Raw property.

## Syntax

```powershell

Get-CloudPC [[-ProvisioningPolicyId] <string>] [[-UserPrincipalName] <string>] [[-Type] <string>] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `ProvisioningPolicyId` | `String` | No |  | Filter to a single provisioning policy. |
| `Type` | `String` | No |  | Shared, Dedicated, or All (default). |
| `UserPrincipalName` | `String` | No |  | Filter to Cloud PCs assigned to a specific user (dedicated only — Graph cannot filter<br />sharedDeviceDetail by user). |

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/cloudPCs
```

## Example 1

```powershell
Get-CloudPC | Format-Table Name,ProvisioningType,AssignedUserUpn,ConnectivityStatus
```

## Example 2

```powershell
Get-CloudPC -ProvisioningPolicyId 8e8a545f-6168-4472-9466-9f05520a5eb3 -Type Shared
```


## Source

[View Get-CloudPC.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Get-CloudPC.ps1)
