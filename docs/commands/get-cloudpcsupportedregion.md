---
id: get-cloudpcsupportedregion
title: Get-CloudPCSupportedRegion
description: "Returns Windows 365 Cloud PC supported regions."
---

# Get-CloudPCSupportedRegion

Returns Windows 365 Cloud PC supported regions.

## Description

Calls the Microsoft Graph beta /deviceManagement/virtualEndpoint/supportedRegions
endpoint and returns normalized WindowsCloudPC.SupportedRegion objects.

The cmdlet requests the common region metadata with $select so Graph includes
non-default fields such as regionGroup and geographicLocationType.

## Syntax

```powershell

Get-CloudPCSupportedRegion [[-RegionStatus] <string>] [[-SupportedSolution] <string>] [[-RegionGroup] <string>] [[-GeographicLocationType] <string>] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `GeographicLocationType` | `String` | No |  | Optional filter for geographic location type, such as usEast, europe, or asia. |
| `RegionGroup` | `String` | No |  | Optional filter for region group, such as usEast, usWest, europeUnion, or australia. |
| `RegionStatus` | `String` | No |  | Optional filter for region status. Common values include available and restricted. |
| `SupportedSolution` | `String` | No |  | Optional filter for supported solution. Defaults to windows365. |

## Output

Emits `WindowsCloudPC.SupportedRegion` rows with `Id`, `DisplayName`, `RegionStatus`, `SupportedSolution`, `RegionGroup`, `GeographicLocationType`, and `Raw`.

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/supportedRegions
```

## Example 1

```powershell
Get-CloudPCSupportedRegion | Format-Table DisplayName,RegionStatus,RegionGroup
```

Lists supported Windows 365 Cloud PC regions.

## Example 2

```powershell
Get-CloudPCSupportedRegion -RegionStatus available -RegionGroup usEast
```

Lists available Windows 365 regions in the usEast region group.

## Example 3

```powershell
Get-CloudPCSupportedRegion -GeographicLocationType europe |
Sort-Object DisplayName
```

Lists supported Windows 365 regions in the Europe geographic location.


## Source

[View Get-CloudPCSupportedRegion.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Get-CloudPCSupportedRegion.ps1)
