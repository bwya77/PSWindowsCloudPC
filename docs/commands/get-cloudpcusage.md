---
id: get-cloudpcusage
title: Get-CloudPCUsage
description: "Reports who is signed in to each Cloud PC and whether it is in use or available."
---

# Get-CloudPCUsage

Reports who is signed in to each Cloud PC and whether it is in use or available.

## Description

Uses the Cloud PC endpoint's connectivityResult.status for shared Cloud
PCs because that signal updates almost immediately for shared devices.
It still reads getCloudPcConnectivityHistory for last sign-in timestamps.
Dedicated Cloud PCs use the beta getRealTimeRemoteConnectionStatus report
endpoint for current sign-in status, then fall back to
getCloudPcConnectivityHistory when the real-time report is unavailable.
The result is enriched with the current user from the
matching Intune managedDevice (dedicated) or sharedDeviceDetail (shared).

UsageStatus values:
inUse         A shared endpoint or dedicated connectivity event says a user is signed in
available     Reachable, nobody signed in or assigned
unavailable   The Cloud PC service marks the PC as unreachable
failed        Last connectivity check failed
unknown       Neither signal returned anything (rare — usually means a brand
new PC whose first telemetry hasn't landed yet)

Source of truth by provisioning type:
Shared      cloudPC.connectivityResult.status from the Cloud PC endpoint.
Connectivity history enriches LastActiveTime only.
Dedicated   getRealTimeRemoteConnectionStatus, then
getCloudPcConnectivityHistory, then
cloudPC.connectivityResult.status.

CurrentUser* fields are populated independently of UsageStatus:
Shared      From sharedDeviceDetail.assignedToUserPrincipalName.
Dedicated   From the managedDevice's most recent usersLoggedOn entry, falling
back to userPrincipalName / userDisplayName on the device.

## Syntax

```powershell

Get-CloudPCUsage [[-CloudPC] <Object[]>] [[-ProvisioningPolicyId] <string>] [[-Type] <string>] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `CloudPC` | `Object[]` | No |  | Pipe in WindowsCloudPC.CloudPC objects from Get-CloudPC, or pass one or<br />more Cloud PC IDs or names. String values are resolved against Get-CloudPC<br />using exact matches on Id, Name, managedDeviceName, or displayName. |
| `ProvisioningPolicyId` | `String` | No |  | Limit the report to a single provisioning policy. |
| `Type` | `String` | No |  | Shared, Dedicated, or All (default). |

## Output

```plaintext
CloudPcName            : CPC-USER-01
ProvisioningType       : Dedicated
ProvisioningPolicyName : W365-Enterprise-Dev
ProvisioningStatus     : provisioned
UsageStatus            : available
SignInStatus           : NotSignedIn
DaysSinceLastSignIn    : 0
LastActiveTime         : 6/15/2026 8:32:13 PM
AssignedUserUpn        : user@contoso.com
CurrentUserUpn         : user@contoso.com
CurrentUserDisplayName : Contoso User
CurrentUserId          : 00000000-0000-0000-0000-000000000000
SessionStart           : 6/15/2026 2:15:26 PM
CloudPcId              : 00000000-0000-0000-0000-000000000000
ManagedDeviceId        : 00000000-0000-0000-0000-000000000000
```

## Graph endpoints

Endpoint details are described in the source and examples.

## Example 1

```powershell
Get-CloudPCUsage | Format-Table CloudPcName,UsageStatus,CurrentUserDisplayName,LastActiveTime
```

## Example 2

```powershell
# Only Cloud PCs with an active session
Get-CloudPCUsage | Where-Object UsageStatus -eq 'inUse'
```

## Example 3

```powershell
# Find idle dedicated PCs (reclamation candidates)
Get-CloudPCUsage -Type Dedicated | Where-Object DaysSinceLastSignIn -ge 30
```

## Example 4

```powershell
# Pre-filter then enrich
Get-CloudPC -Type Dedicated | Get-CloudPCUsage
```

## Example 5

```powershell
# Resolve one Cloud PC by ID or name
Get-CloudPCUsage -CloudPC '<cloud-pc-id-or-name>'
```


## Source

[View Get-CloudPCUsage.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Get-CloudPCUsage.ps1)
