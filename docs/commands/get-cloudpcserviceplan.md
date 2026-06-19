---
id: get-cloudpcserviceplan
title: Get-CloudPCServicePlan
description: "Returns Windows 365 Cloud PC service plans."
---

# Get-CloudPCServicePlan

Returns Windows 365 Cloud PC service plans.

## Description

Calls the Microsoft Graph beta
https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/servicePlans
endpoint and returns the Cloud PC service plans available to the tenant.

The Graph servicePlans API does not support OData query parameters, so
DisplayName and Type filters are applied client-side.

## Syntax

```powershell

Get-CloudPCServicePlan [[-DisplayName] <string>] [[-Type] <string>] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `DisplayName` | `String` | No | `Name`, `ServicePlanName` | Optional exact display name filter. Alias: Name. |
| `Type` | `String` | No |  | Optional service plan type filter, such as enterprise or business. |

## Output

```plaintext
Id            : 00000000-0000-0000-0000-000000000000
DisplayName   : Cloud PC Enterprise 4vCPU/16GB/128GB
Type          : enterprise
VCpuCount     : 4
RamGB         : 16
StorageGB     : 128
UserProfileGB : 25
```

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/servicePlans
```

## Example 1

```powershell
Get-CloudPCServicePlan | Format-Table DisplayName,Type,VCpuCount,RamGB,StorageGB
```

## Example 2

```powershell
Get-CloudPCServicePlan -Type enterprise |
Sort-Object VCpuCount,RamGB,StorageGB
```

## Example 3

```powershell
Get-CloudPCServicePlan -DisplayName 'Cloud PC Enterprise 4vCPU/16GB/128GB'
```


## Source

[View Get-CloudPCServicePlan.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Get-CloudPCServicePlan.ps1)
