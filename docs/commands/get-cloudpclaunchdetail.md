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
launch URI using the ms-cloudpc:connect protocol. If -UserId is omitted, the
cmdlet uses the signed-in Graph account as the launch username when available.

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
| `UserId` | `String` | No | `AssignedUserUpn`, `UserPrincipalName` | Optional user ID or UPN for the /users/&#123;userId&#125;/cloudPCs/&#123;id&#125;/retrieveCloudPcLaunchDetail<br />form. If omitted, the cmdlet uses /me/cloudPCs/&#123;id&#125;/retrieveCloudPcLaunchDetail and uses<br />the signed-in Graph account for the generated Windows App launch URI. |

## Output

```plaintext
CloudPcId                                      : 00000000-0000-0000-0000-000000000000
CloudPcName                                    : 00000000-0000-0000-0000-000000000000
UserId                                         : me
CloudPcLaunchUrl                               : https://rdweb.wvd.microsoft.com/api/arm/weblaunch/tenants/00000000-0000-0000-0000-000000000000/resources/00000000-0000-0000-0000-000000000000
WindowsAppLaunchUri                            : ms-cloudpc:connect?cpcid=00000000-0000-0000-0000-000000000000&username=user%40contoso.com&environment=PROD&source=IWP&rdlaunchurl=https%3A%2F%2Frdweb.wvd.microsoft.com%2Fapi%2Farm%2Fweblaunch%2Ftenants%2F00000000-0000-0000-0000-000000000000%2Fresources%2F00000000-0000-0000-0000-000000000000
Windows365SwitchCompatible                     : True
Windows365SwitchCompatibilityFailureReasonType :
LaunchDetailStatus                             : Available
ErrorMessage                                   :
Raw                                            : {[windows365SwitchCompatible, True], [cloudPcId, 00000000-0000-0000-0000-000000000000],
                                                 [cloudPcLaunchUrl, https://rdweb.wvd.microsoft.com/api/arm/weblaunch/tenants/00000000-0000-0000-0000-000000000000/resources/00000000-0000-0000-0000-000000000000], [@odata.context,
                                                 https://graph.microsoft.com/v1.0/$metadata#microsoft.graph.cloudPcLaunchDetail]…}
```

## Graph endpoints

```text
/v1.0/me/cloudPCs/{id}/retrieveCloudPcLaunchDetail
/v1.0/users/{userId}/cloudPCs/{id}/retrieveCloudPcLaunchDetail
```

## Example 1

```powershell
Get-CloudPCLaunchDetail -Id 'a20d556d-85f7-88cc-bb9c-08d9902bb7bb'
```

Gets launch details for a Cloud PC that belongs to the signed-in user. The generated
Windows App launch URI uses the signed-in Graph account as the username.

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
