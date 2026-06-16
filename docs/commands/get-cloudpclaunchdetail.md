---
id: get-cloudpclaunchdetail
title: Get-CloudPCLaunchDetail
description: "Gets launch details for one or more Windows 365 Cloud PCs."
---

# Get-CloudPCLaunchDetail

Gets launch details for one or more Windows 365 Cloud PCs.

## Description

Calls the Microsoft Graph v1.0 retrieveCloudPcLaunchDetail function for a Cloud PC.
The response includes the Cloud PC launch URL and Windows 365 Switch compatibility
details. When a username is available, the output also includes a Windows App
launch URI using the ms-cloudpc:connect protocol.

Cloud PCs that are still provisioning might not have launch details yet. In that
case, Graph can return 404 NotFound. The cmdlet emits a normal result row with
LaunchDetailStatus = 'Unavailable' instead of writing an error.

By default, the cmdlet queries /me/cloudPCs/&#123;id&#125;/retrieveCloudPcLaunchDetail. Use
-UserId to query /users/&#123;userId&#125;/cloudPCs/&#123;id&#125;/retrieveCloudPcLaunchDetail instead.

## Syntax

```powershell

Get-CloudPCLaunchDetail -CloudPC <CloudPC> [-UserId <string>] [<CommonParameters>]

Get-CloudPCLaunchDetail -Id <string> [-UserId <string>] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `CloudPC` | `Object` | Yes |  | A WindowsCloudPC.CloudPC object (as returned by Get-CloudPC). Accepts pipeline input. |
| `Id` | `String` | Yes | `CloudPcId` | The Cloud PC ID (GUID) when you do not have a CloudPC object handy. |
| `UserId` | `String` | No | `AssignedUserUpn`, `UserPrincipalName` | Optional user ID or UPN for the /users/&#123;userId&#125;/cloudPCs/&#123;id&#125;/retrieveCloudPcLaunchDetail<br />form. If omitted, the cmdlet uses /me/cloudPCs/&#123;id&#125;/retrieveCloudPcLaunchDetail. |

## Graph endpoints

```text
/v1.0/me/cloudPCs/{id}/retrieveCloudPcLaunchDetail
/v1.0/users/{userId}/cloudPCs/{id}/retrieveCloudPcLaunchDetail
```

## Example 1

```powershell
Get-CloudPCLaunchDetail -Id 'a20d556d-85f7-88cc-bb9c-08d9902bb7bb'
```

Gets launch details for a Cloud PC that belongs to the signed-in user.

## Example 2

```powershell
Get-CloudPCLaunchDetail -Id 'a20d556d-85f7-88cc-bb9c-08d9902bb7bb' -UserId 'user@contoso.com'
```

Gets launch details by using the /users/&#123;userId&#125;/cloudPCs/&#123;id&#125; endpoint form.

## Example 3

```powershell
Get-CloudPC | Get-CloudPCLaunchDetail | Format-Table CloudPcName,Windows365SwitchCompatible,WindowsAppLaunchUri
```

Gets launch details for Cloud PCs returned by Get-CloudPC.


## Source

[View Get-CloudPCLaunchDetail.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Get-CloudPCLaunchDetail.ps1)
