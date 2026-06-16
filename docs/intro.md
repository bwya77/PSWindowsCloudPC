---
id: intro
title: Overview
description: Documentation for the WindowsCloudPC PowerShell module.
slug: /
---

# WindowsCloudPC

WindowsCloudPC is a PowerShell module for Windows 365 administrators who want fast, scriptable access to Cloud PC inventory and operations through Microsoft Graph beta APIs.

Use it when you need to:

- Audit Cloud PCs, provisioning policies, user assignments, regions, settings, and launch details.
- Report Cloud PC usage and identify idle or recently active devices.
- View restore point snapshots and create new snapshots at single-device, user, policy, or tenant scope.
- Reprovision Cloud PCs safely with `-WhatIf`, `-Force`, and explicit exclusions.
- Inspect cloud licensing allotments and available license capacity.

```powershell
Install-Module WindowsCloudPC -Scope CurrentUser
Connect-CloudPC
Get-CloudPCUsage | Format-Table CloudPcName,UsageStatus,DaysSinceLastSignIn
```

## Documentation map

| Page | Use it for |
| --- | --- |
| [Getting started](/docs/getting-started) | Install, import, connect, and run the first commands. |
| [Inventory and reporting](/docs/inventory-and-reporting) | Cloud PC inventory, policy grouping, usage, launch detail, and remote actions. |
| [Snapshots](/docs/snapshots) | Viewing restore points and creating snapshots. |
| [Reprovisioning](/docs/reprovisioning) | Reprovisioning one Cloud PC or all Cloud PCs assigned to a provisioning policy. |
| [Licensing](/docs/licensing) | Cloud licensing allotment discovery. |
| [Permissions](/docs/permissions) | Graph scopes used by each command area. |
| [Command reference](/docs/commands/) | Generated help for every public command. |

:::info
The module uses Microsoft Graph beta endpoints because several Windows 365 Cloud PC operations are only exposed there. Test automation in a non-production tenant before using write operations broadly.
:::
