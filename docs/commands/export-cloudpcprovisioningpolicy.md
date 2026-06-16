---
id: export-cloudpcprovisioningpolicy
title: Export-CloudPCProvisioningPolicy
description: "Exports a Windows 365 Cloud PC provisioning policy as reusable JSON."
---

# Export-CloudPCProvisioningPolicy

Exports a Windows 365 Cloud PC provisioning policy as reusable JSON.

## Description

Exports the create-safe provisioning policy body and assignment targets for a
policy returned by Microsoft Graph beta. Read-only Graph fields are not placed
in CreateBody, so the JSON can be passed to New-CloudPCProvisioningPolicy.

Assignments are exported separately because Graph creates the provisioning
policy first, then assigns it with /provisioningPolicies/&#123;id&#125;/assign.

## Syntax

```powershell

Export-CloudPCProvisioningPolicy -Id <string> [-Path <string>] [-Force] [<CommonParameters>]

Export-CloudPCProvisioningPolicy -Policy <Object> [-Path <string>] [-Force] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `Force` | `SwitchParameter` | No |  | Overwrite Path when it already exists. |
| `Id` | `String` | Yes | `ProvisioningPolicyId` | The provisioning policy ID to export. |
| `Path` | `String` | No |  | Optional JSON file path to write. If omitted, the export object is emitted. |
| `Policy` | `Object` | Yes |  | A WindowsCloudPC.ProvisioningPolicy object returned by Get-CloudPCProvisioningPolicy. |

## Graph endpoints

Endpoint details are described in the source and examples.

## Example 1

```powershell
Get-CloudPCProvisioningPolicy -Id '<policy-id>' |
Export-CloudPCProvisioningPolicy -Path .\policy.json
```

## Example 2

```powershell
Export-CloudPCProvisioningPolicy -Id '<policy-id>' |
New-CloudPCProvisioningPolicy -DisplayName 'Copy of source policy' -WhatIf
```


## Source

[View Export-CloudPCProvisioningPolicy.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Export-CloudPCProvisioningPolicy.ps1)
