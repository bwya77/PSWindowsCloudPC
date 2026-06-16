---
id: get-cloudpclicensingallotment
title: Get-CloudPCLicensingAllotment
description: "Returns Microsoft Graph cloud licensing allotments."
---

# Get-CloudPCLicensingAllotment

Returns Microsoft Graph cloud licensing allotments.

## Description

Calls the Microsoft Graph beta /admin/cloudLicensing/allotments endpoint
and returns normalized WindowsCloudPC.LicensingAllotment objects.

By default, the cmdlet lists every allotment. Pass -Id to retrieve a
single allotment. Optional OData query parameters can be used to shape
the Graph response for testing the beta endpoint.

## Syntax

```powershell

Get-CloudPCLicensingAllotment [[-Id] <string>] [-Select <string[]>] [-Expand <string>] [-Filter <string>] [-Top <int>] [-Apply <string>] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `Apply` | `String` | No |  | Optional OData $apply expression for list queries. |
| `Expand` | `String` | No |  | Optional OData $expand expression. |
| `Filter` | `String` | No |  | Optional OData $filter expression. |
| `Id` | `String` | No | `AllotmentId` | Optional allotment ID. When provided, the cmdlet retrieves only that<br />allotment. |
| `Select` | `String[]` | No | `Property` | Optional OData $select fields. |
| `Top` | `Int32` | No |  | Optional OData $top value for list queries. |

## Graph endpoints

```text
/beta/admin/cloudLicensing/allotments/
/beta/admin/cloudLicensing/allotments
```

## Example 1

```powershell
Get-CloudPCLicensingAllotment | Format-Table SkuPartNumber,AllottedUnits,ConsumedUnits,AvailableUnits
```

Lists licensing allotments with capacity and consumption.

## Example 2

```powershell
Get-CloudPCLicensingAllotment -Id 'fde42873-30b6-436b-b361-21af5a6b84ae'
```

Gets one licensing allotment by ID.

## Example 3

```powershell
Get-CloudPCLicensingAllotment -Select id,skuPartNumber,allottedUnits,consumedUnits -Expand 'waitingMembers($select=id,waitingSinceDateTime)'
```

Lists licensing allotments with selected fields and expanded waiting members.


## Source

[View Get-CloudPCLicensingAllotment.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Get-CloudPCLicensingAllotment.ps1)
