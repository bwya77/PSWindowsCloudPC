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

Name is the Cloud PC displayName, which is the value changed by Rename-CloudPC.
ManagedDeviceName is returned separately because it can remain unchanged after a
Cloud PC display name rename.

The request selects connectivityResult and sends
Prefer: include-unknown-enum-members so Graph returns evolvable enum
values such as inUse and underServiceMaintenance.

## Syntax

```powershell

Get-CloudPC [[-ProvisioningPolicyId] <string>] [[-UserPrincipalName] <string>] [[-Id] <string>] [[-Name] <string>] [[-ProvisioningStatus] <string[]>] [[-Type] <string>] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `Id` | `String` | No | `CloudPcId` | Return a single Cloud PC by Cloud PC ID. |
| `Name` | `String` | No | `DisplayName`, `ManagedDeviceName` | Filter by Cloud PC display name or managed device name. Exact matches are used<br />unless the value contains wildcard characters. Aliases: DisplayName, ManagedDeviceName. |
| `ProvisioningPolicyId` | `String` | No |  | Filter to a single provisioning policy. |
| `ProvisioningStatus` | `String[]` | No |  | Filter by one or more Cloud PC statuses, such as provisioned,<br />inGracePeriod, or deprovisioning. |
| `Type` | `String` | No |  | Shared, Dedicated, or All (default). |
| `UserPrincipalName` | `String` | No |  | Filter to Cloud PCs assigned to a specific user (dedicated only — Graph cannot filter<br />sharedDeviceDetail by user). |

## Output

```plaintext
Id                     : 00000000-0000-0000-0000-000000000000
Name                   : Finance-CloudPC-01
DisplayName            : Finance-CloudPC-01
ManagedDeviceName      : CPC-USER-01
ProvisioningType       : Dedicated
ProvisioningPolicyName : W365-Flex-Dedicated
ProvisioningPolicyId   : 00000000-0000-0000-0000-000000000000
ProvisioningStatus     : provisioned
ServicePlanName        : Cloud PC Frontline 4vCPU/16GB/128GB
AssignedUserUpn        : user@contoso.com
ManagedDeviceId        : 00000000-0000-0000-0000-000000000000
AadDeviceId            : 00000000-0000-0000-0000-000000000000
LastModifiedDateTime   : 6/9/2026 1:08:31 AM
Raw                    : {[sharedDeviceDetail, ], [provisioningType, sharedByUser], [managedDeviceId,
                         00000000-0000-0000-0000-000000000000], [provisioningPolicyId, 00000000-0000-0000-0000-000000000000]…}
```

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/cloudPCs
/beta/deviceManagement/virtualEndpoint/cloudPCs/
```

## Example 1

```powershell
Get-CloudPC | Format-Table Name,ProvisioningType,AssignedUserUpn,ConnectivityStatus
```

## Example 2

```powershell
Get-CloudPC -ProvisioningPolicyId 8e8a545f-6168-4472-9466-9f05520a5eb3 -Type Shared
```

## Example 3

```powershell
Get-CloudPC -Id '95194d88-cec5-4b65-af62-26dbd1814364'
```

## Example 4

```powershell
Get-CloudPC -Name 'CFD-brad-*'
```

## Example 5

```powershell
Get-CloudPC -ProvisioningStatus inGracePeriod
```

## Example 6

```powershell
Get-CloudPC -ProvisioningStatus inGracePeriod,deprovisioning
```


## Source

[View Get-CloudPC.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Get-CloudPC.ps1)
