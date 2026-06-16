---
id: get-cloudpcusage
title: Get-CloudPCUsage
description: "Reports who is signed in to each Cloud PC and whether it is in use or available."
---

# Get-CloudPCUsage

Reports who is signed in to each Cloud PC and whether it is in use or available.

## Description

Calls the beta /reports/getRealTimeRemoteConnectionStatus(cloudPcId='...') endpoint
per Cloud PC — the same signal the Intune admin center's "Sign in status" column
uses — and enriches it with the current user from the matching Intune managedDevice
(dedicated) or sharedDeviceDetail (shared).

UsageStatus values:
inUse         A user is currently signed in (SignInStatus = SignedIn)
available     Reachable, nobody signed in (SignInStatus = NotSignedIn)
unavailable   The Cloud PC service marks the PC as unreachable
failed        Last connectivity check failed
unknown       Neither signal returned anything (rare — usually means a brand
new PC whose first telemetry hasn't landed yet)

The real-time report is the primary source of truth. If it fails (transient Graph
error, beta endpoint hiccup, etc.) the function falls back to the cloudPC's own
connectivityResult.status so you still get a useful value.

CurrentUser* fields are populated independently of UsageStatus:
Shared      From sharedDeviceDetail.assignedToUserPrincipalName.
Dedicated   From the managedDevice's most recent usersLoggedOn entry, falling
back to userPrincipalName / userDisplayName on the device.

## Syntax

```powershell

Get-CloudPCUsage [[-CloudPC] <CloudPC[]>] [[-ProvisioningPolicyId] <string>] [[-Type] <string>] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `CloudPC` | `PSObject[]` | No |  | Pipe in WindowsCloudPC.CloudPC objects from Get-CloudPC. Anything else fails<br />parameter binding (so a typo like Get-CloudPCUsage -CloudPC 'test' errors loudly<br />instead of returning blank rows). |
| `ProvisioningPolicyId` | `String` | No |  | Limit the report to a single provisioning policy. |
| `Type` | `String` | No |  | Shared, Dedicated, or All (default). |

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


## Source

[View Get-CloudPCUsage.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Get-CloudPCUsage.ps1)
