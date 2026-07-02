---
id: get-cloudpcgalleryimage
title: Get-CloudPCGalleryImage
description: "Returns Windows 365 Cloud PC gallery images."
---

# Get-CloudPCGalleryImage

Returns Windows 365 Cloud PC gallery images.

## Description

Calls the Microsoft Graph beta
https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/galleryImages
endpoint and returns Microsoft gallery images available for Cloud PC provisioning.

## Syntax

```powershell

Get-CloudPCGalleryImage [[-Id] <string>] [[-DisplayName] <string>] [[-Status] <string>] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `DisplayName` | `String` | No | `Name` | Optional exact display name filter. Alias: Name. |
| `Id` | `String` | No |  | Optional exact gallery image ID filter. |
| `Status` | `String` | No |  | Optional gallery image status filter. |

## Output

```plaintext
Id               : microsoftwindowsdesktop_windows-ent-cpc_win11-24H2-ent-cpc
DisplayName      : Windows 11 Enterprise 24H2
OfferDisplayName : Windows 11 Enterprise
SkuDisplayName   : 24H2
RecommendedSku   : light
Status           : supported
SizeGB           : 64
OsVersionNumber  : 10.0.26100.0
```

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/galleryImages
```

## Example 1

```powershell
Get-CloudPCGalleryImage | Format-Table DisplayName,Status,RecommendedSku,SizeGB
```

## Example 2

```powershell
Get-CloudPCGalleryImage -DisplayName 'Windows 11 Enterprise 24H2'
```

## Example 3

```powershell
Get-CloudPCGalleryImage -Status supported
```


## Source

[View Get-CloudPCGalleryImage.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Get-CloudPCGalleryImage.ps1)
