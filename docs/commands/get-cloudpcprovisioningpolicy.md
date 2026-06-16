---
id: get-cloudpcprovisioningpolicy
title: Get-CloudPCProvisioningPolicy
description: "Returns Windows 365 Cloud PC provisioning policies, with assigned groups resolved."
---

# Get-CloudPCProvisioningPolicy

Returns Windows 365 Cloud PC provisioning policies, with assigned groups resolved.

## Description

Wraps /beta/deviceManagement/virtualEndpoint/provisioningPolicies?$expand=assignments
and returns normalized PSCustomObjects (PSTypeName = 'WindowsCloudPC.ProvisioningPolicy').

Each policy exposes a ProvisioningPolicyId property (mirror of Id) so it pipes cleanly
into Get-CloudPC, Get-CloudPCUsage, and Get-CloudPCByProvisioningPolicy:

Get-CloudPCProvisioningPolicy | Get-CloudPC
Get-CloudPCProvisioningPolicy | Get-CloudPCUsage
Get-CloudPCProvisioningPolicy | Get-CloudPCByProvisioningPolicy

To see which Cloud PCs belong to which policy (and a count), use
Get-CloudPCByProvisioningPolicy.

## Syntax

```powershell

Get-CloudPCProvisioningPolicy [[-Id] <string>] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `Id` | `String` | No | `ProvisioningPolicyId` | Optional: fetch a single policy by id. Accepts pipeline input by property name<br />(binds to Id / ProvisioningPolicyId). |

## Output

```plaintext
Id                      : 00000000-0000-0000-0000-000000000000
ProvisioningPolicyId    : 00000000-0000-0000-0000-000000000000
DisplayName             : W365-Flex-Shared
Description             :
ProvisioningType        : sharedByEntraGroup
ImageDisplayName        : Windows 11 Enterprise + Microsoft 365 Apps 25H2
ImageType               : gallery
EnableSingleSignOn      : True
LocalAdminEnabled       :
CloudPcNamingTemplate   : CFS-%RAND:11%
CloudPcGroupDisplayName :
ManagedBy               : windows365
GracePeriodInHours      :
DomainJoinTypes         : azureADJoin
Assignments             : @{GroupId=00000000-0000-0000-0000-000000000000; GroupName=W365-Flex-Shared-Users;
                          TargetType=#microsoft.graph.cloudPcManagementGroupAssignmentTarget}
AssignedGroupIds        : {00000000-0000-0000-0000-000000000000}
AssignedGroupNames      : {W365-Flex-Shared-Users}
Raw                     : {[lastModifiedBy, 00000000-0000-0000-0000-000000000000], [autopatch, ], [description, ], [autopilotConfiguration,
                          System.Collections.Hashtable]…}
```

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/provisioningPolicies/$Id
/beta/deviceManagement/virtualEndpoint/provisioningPolicies?$expand=assignments
```

## Example 1

```powershell
Get-CloudPCProvisioningPolicy | Format-Table DisplayName,ProvisioningType,AssignedGroupNames
```

## Example 2

```powershell
# Usage report grouped by policy
Get-CloudPCProvisioningPolicy |
Get-CloudPCUsage |
Group-Object ProvisioningPolicyName |
Format-Table Name,Count
```

## Example 3

```powershell
# Cloud PCs grouped under each policy
Get-CloudPCByProvisioningPolicy | Format-Table DisplayName,ProvisioningType,CloudPCCount
```


## Source

[View Get-CloudPCProvisioningPolicy.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Get-CloudPCProvisioningPolicy.ps1)
