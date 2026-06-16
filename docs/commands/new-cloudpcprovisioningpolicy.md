---
id: new-cloudpcprovisioningpolicy
title: New-CloudPCProvisioningPolicy
description: "Creates a Windows 365 Cloud PC provisioning policy from an export."
---

# New-CloudPCProvisioningPolicy

Creates a Windows 365 Cloud PC provisioning policy from an export.

## Description

Creates a new Cloud PC provisioning policy by POSTing the exported CreateBody
to /beta/deviceManagement/virtualEndpoint/provisioningPolicies.

Use Export-CloudPCProvisioningPolicy to produce the JSON. Assignment targets
are included in the export, but are only applied when -Assign is specified.

## Syntax

```powershell

New-CloudPCProvisioningPolicy -Path <string> [-DisplayName <string>] [-Description <string>] [-RegionName <string>] [-IncludeAutopilotConfiguration] [-AllotmentLicensesCount <int>] [-Assign] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]

New-CloudPCProvisioningPolicy -InputObject <Object> [-DisplayName <string>] [-Description <string>] [-RegionName <string>] [-IncludeAutopilotConfiguration] [-AllotmentLicensesCount <int>] [-Assign] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `AllotmentLicensesCount` | `Int32` | No |  | Override the exported allotment count for shared by Entra group assignment<br />targets. Use this when copying a Flex Shared policy and the source count<br />exceeds remaining capacity. |
| `Assign` | `SwitchParameter` | No |  | Recreate exported assignment targets on the newly created policy. |
| `Description` | `String` | No |  | Optional replacement description for the new policy. |
| `DisplayName` | `String` | No |  | Optional replacement display name for the new policy. |
| `Force` | `SwitchParameter` | No |  | Suppress confirmation prompts. Equivalent to -Confirm:$false. |
| `IncludeAutopilotConfiguration` | `SwitchParameter` | No |  | Include the exported Autopilot configuration in the create request.<br />By default, this is omitted because Graph can reject copied device<br />preparation profile IDs even when they were returned on the source policy. |
| `InputObject` | `Object` | Yes |  | Export object created by Export-CloudPCProvisioningPolicy. |
| `Path` | `String` | Yes |  | Path to a JSON file created by Export-CloudPCProvisioningPolicy. |
| `RegionName` | `String` | No |  | Optional supported region name to use for Microsoft Entra joined policies.<br />This overrides exported automatic target geography values. |

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/provisioningPolicies
/beta/deviceManagement/virtualEndpoint/provisioningPolicies/{id}/assign
```

## Example 1

```powershell
New-CloudPCProvisioningPolicy -Path .\policy.json -DisplayName 'Copied Policy' -WhatIf
```

## Example 2

```powershell
Export-CloudPCProvisioningPolicy -Id '<policy-id>' |
New-CloudPCProvisioningPolicy -DisplayName 'Copied Policy' -Assign -Force
```


## Source

[View New-CloudPCProvisioningPolicy.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/New-CloudPCProvisioningPolicy.ps1)
