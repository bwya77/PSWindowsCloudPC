---
id: get-cloudpcreport
title: Get-CloudPCReport
description: "Retrieves Windows 365 Cloud PC report rows from Microsoft Graph beta stream reports."
---

# Get-CloudPCReport

Retrieves Windows 365 Cloud PC report rows from Microsoft Graph beta stream reports.

## Description

Calls the Microsoft Graph beta Cloud PC report stream actions under
/deviceManagement/virtualEndpoint/reports and parses the downloaded
report file into objects. Graph returns these reports as files with a
Schema array and a Values array. The cmdlet reads each Schema column,
converts DateTime and common numeric types, and emits one
WindowsCloudPC.ReportRow object per row.

The ReportName parameter accepts only cloudPcReportName enum members
that were verified to return report streams in a live tenant. Deprecated
reports, tenant-state-dependent reports that returned Graph 400s, and
enum values without a callable Graph action are intentionally excluded.

## Syntax

```powershell

Get-CloudPCReport [-ReportName] <string> [-CloudPcId <string>] [-ActivityId <string>] [-Select <string[]>] [-Filter <string>] [-Search <string>] [-GroupBy <string[]>] [-OrderBy <string[]>] [-Skip <int>] [-Top <int>] [-OutputFilePath <string>] [-Raw] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `ActivityId` | `String` | No |  | Optional remote connection activity ID used to build the required<br />ActivityId filter for rawRemoteConnectionReports. If Filter is also<br />provided, the ActivityId clause is combined with it. |
| `CloudPcId` | `String` | No |  | Optional Cloud PC ID used to build the required CloudPcId filter for<br />reports that are scoped to one Cloud PC, such as<br />remoteConnectionHistoricalReports. If Filter is also provided, the<br />CloudPcId clause is combined with it. |
| `Filter` | `String` | No |  | Optional OData filter expression for the report action. |
| `GroupBy` | `String[]` | No |  | Optional report columns to group by. For Graph report actions that<br />support groupBy, this usually must match Select. |
| `OrderBy` | `String[]` | No |  | Optional report columns or expressions to sort by. |
| `OutputFilePath` | `String` | No |  | Optional path where the raw Graph report file should be saved. When not<br />provided, a temporary file is used and removed after parsing. |
| `Raw` | `SwitchParameter` | No |  | Return a WindowsCloudPC.ReportPayload object containing the parsed file,<br />schema, values, action name, and output file path instead of row objects. |
| `ReportName` | `String` | Yes |  | The Microsoft Graph beta cloudPcReportName enum member to retrieve. |
| `Search` | `String` | No |  | Optional search string for the report action. |
| `Select` | `String[]` | No | `Property` | Optional report columns to request. Graph returns only selected columns<br />when the target report action supports select.<br />For rawRemoteConnectionReports, the Graph stream uses Timestamp and<br />AvailableBandwidthInMBps column names. Common aliases SignInDateTime and<br />AvailableBandwidthInMbps are normalized automatically. |
| `Skip` | `Int32` | No |  | Optional number of rows to skip. |
| `Top` | `Int32` | No |  | Optional number of rows to return. |

## Output

```plaintext
ReportName        : remoteConnectionHistoricalReports
Action            : getRemoteConnectionHistoricalReports
TotalRowCount     : 10
OutputFilePath    : C:\Users\user\AppData\Local\Temp\windowscloudpc-report-remoteConnectionHistoricalReports-00000000000000000000000000000000.json
ActivityId        : 3cd56639-c1ee-4d24-b994-5da0d5b90000
CloudPcId         : 198294a2-4d1d-4c28-bb81-74c3f495a9b2
ManagedDeviceName : CPC-USER-01
SignInDateTime    : 6/15/2026 12:53:50 PM
SignOutDateTime   : 6/15/2026 1:04:57 PM
UsageInHour       : 0.185
RawValues         : {3cd56639-c1ee-4d24-b994-5da0d5b90000, 198294a2-4d1d-4c28-bb81-74c3f495a9b2, CPC-USER-01, 2026-06-15T17:53:50...}
Raw               : {[TotalRowCount, 10], [Schema, System.Object[]], [Values, System.Object[]]}
```

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/reports/$($definition.Action)
```

## Example 1

```powershell
$pc = Get-CloudPC | Select-Object -First 1
Get-CloudPCReport -ReportName remoteConnectionHistoricalReports -CloudPcId $pc.Id -Top 50 |
Format-Table ManagedDeviceName,SignInDateTime,SignOutDateTime,UsageInHour
```

## Example 2

```powershell
$activity = Get-CloudPCReport -ReportName remoteConnectionHistoricalReports -CloudPcId '<cloud-pc-id>' -Top 1
Get-CloudPCReport -ReportName rawRemoteConnectionReports -ActivityId $activity.ActivityId -Select SignInDateTime,RoundTripTimeInMs,AvailableBandwidthInMbps |
Sort-Object Timestamp -Descending
```

## Example 3

```powershell
Get-CloudPCReport -ReportName frontlineLicenseUsageReport -Top 100 |
Format-Table Timestamp,DisplayName,LicenseCount,ClaimedLicenseCount
```

## Example 4

```powershell
Get-CloudPCReport -ReportName regionalConnectionQualityTrendReport -Top 50 |
Format-Table GatewayRegionName,WeeklyAvgRoundTripTimeInMs,WeeklyAvgAvailableBandwidthInMbps
```


## Source

[View Get-CloudPCReport.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Get-CloudPCReport.ps1)
