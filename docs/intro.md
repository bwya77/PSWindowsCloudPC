---
id: intro
title: WindowsCloudPC documentation
description: Docusaurus documentation for the WindowsCloudPC PowerShell module.
slug: /
---

# WindowsCloudPC

WindowsCloudPC is a PowerShell module for managing and querying Windows 365 Cloud PCs through Microsoft Graph beta APIs.

The documentation site provides:

- Install and authentication guidance.
- A detailed command reference generated from comment-based help.
- Examples for inventory, usage reporting, snapshots, reprovisioning, and licensing allotments.
- PowerShell Gallery stats such as the published version and download count.

```powershell
Install-Module WindowsCloudPC -Scope CurrentUser
Connect-CloudPC
Get-CloudPCUsage | Format-Table CloudPcName,UsageStatus,DaysSinceLastSignIn
```

