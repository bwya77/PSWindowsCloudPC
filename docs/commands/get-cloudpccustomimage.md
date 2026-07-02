---
id: get-cloudpccustomimage
title: Get-CloudPCCustomImage
description: "Returns Windows 365 Cloud PC custom device images."
---

# Get-CloudPCCustomImage

Returns Windows 365 Cloud PC custom device images.

## Description

Calls the Microsoft Graph beta
https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/deviceImages
endpoint and returns custom OS images uploaded for Cloud PC provisioning.

## Syntax

```powershell

Get-CloudPCCustomImage [[-Id] <string>] [[-DisplayName] <string>] [[-Status] <string>] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `DisplayName` | `String` | No | `Name` | Optional exact display name filter. Alias: Name. |
| `Id` | `String` | No |  | Optional exact custom image ID filter. |
| `Status` | `String` | No |  | Optional image status filter. |

## Output

```plaintext
Id                    : 00000000-0000-0000-0000-000000000000
DisplayName           : Win11-Corp-Image
OperatingSystem       : Windows 11 Enterprise
OsBuildNumber         : 23H2
OsVersionNumber       : 10.0.22631.3593
Version               : 1.0.0
Status                : ready
OsStatus              : supported
SizeGB                : 64
SourceImageResourceId : /subscriptions/.../resourceGroups/rg/providers/Microsoft.Compute/images/win11-corp
```

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/deviceImages
```

## Example 1

```powershell
Get-CloudPCCustomImage | Format-Table DisplayName,Status,OperatingSystem,OsBuildNumber
```

## Example 2

```powershell
Get-CloudPCCustomImage -DisplayName 'Win11-Corp-Image'
```

## Example 3

```powershell
Get-CloudPCCustomImage -Status ready
```


## Source

[View Get-CloudPCCustomImage.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Get-CloudPCCustomImage.ps1)
