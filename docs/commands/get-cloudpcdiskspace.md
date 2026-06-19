---
id: get-cloudpcdiskspace
title: Get-CloudPCDiskSpace
description: "Reports OS disk capacity and free space for Windows 365 Cloud PCs."
---

# Get-CloudPCDiskSpace

Reports OS disk capacity and free space for Windows 365 Cloud PCs.

## Description

Joins Windows 365 Cloud PC inventory with the associated Intune
managedDevice record and calculates total storage, free storage, used
storage, percent free, and percent used for the Cloud PC OS disk.

Microsoft Graph exposes disk metrics on the
https://graph.microsoft.com/beta/deviceManagement/managedDevices
endpoint, not on the cloudPC resource. The values come from Intune
inventory and reflect the device's last check-in time, shown as
LastSyncDateTime.

## Syntax

```powershell

Get-CloudPCDiskSpace [[-CloudPC] <Object[]>] [[-ProvisioningPolicyId] <string>] [[-Type] <string>] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `CloudPC` | `Object[]` | No |  | Pipe in WindowsCloudPC.CloudPC objects from Get-CloudPC, or pass one or<br />more Cloud PC IDs or names. String values are resolved against Get-CloudPC<br />using exact matches on Id, Name, managedDeviceId, managedDeviceName, or<br />displayName. |
| `ProvisioningPolicyId` | `String` | No |  | Limit the report to a single provisioning policy. |
| `Type` | `String` | No |  | Shared, Dedicated, or All (default). |

## Output

```plaintext
CloudPcName            : CPC-USER-01
ManagedDeviceName      : CPC-USER-01
ProvisioningType       : Dedicated
ProvisioningPolicyName : W365-Enterprise-Dev
AssignedUserUpn        : user@contoso.com
TotalStorageGB         : 127.45
FreeStorageGB          : 88.90
UsedStorageGB          : 38.54
PercentFree            : 69.80
PercentUsed            : 30.20
LastSyncDateTime       : 6/19/2026 11:30:00 AM
CloudPcId              : 00000000-0000-0000-0000-000000000000
ManagedDeviceId        : 00000000-0000-0000-0000-000000000000
```

## Graph endpoints

```text
/beta/deviceManagement/managedDevices
```

## Example 1

```powershell
Get-CloudPCDiskSpace |
Sort-Object PercentFree |
Format-Table CloudPcName,FreeStorageGB,TotalStorageGB,PercentFree,LastSyncDateTime
```

## Example 2

```powershell
Get-CloudPC -Type Dedicated | Get-CloudPCDiskSpace
```

## Example 3

```powershell
Get-CloudPCDiskSpace -CloudPC '<cloud-pc-id-or-name>'
```

## Example 4

```powershell
Get-CloudPCDiskSpace |
Where-Object PercentFree -lt 15 |
Format-Table CloudPcName,AssignedUserUpn,FreeStorageGB,PercentFree
```


## Source

[View Get-CloudPCDiskSpace.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Get-CloudPCDiskSpace.ps1)
