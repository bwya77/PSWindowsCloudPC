---
id: getting-started
title: Getting started
description: Install and start using the WindowsCloudPC PowerShell module.
---

# Getting started

## Install from PowerShell Gallery

```powershell
Install-Module WindowsCloudPC -Scope CurrentUser
```

## Import from source

```powershell
git clone https://github.com/bwya77/PSWindowsCloudPC.git
Import-Module .\PSWindowsCloudPC\WindowsCloudPC.psd1 -Force
```

## Connect to Microsoft Graph

```powershell
Connect-CloudPC
```

`Connect-CloudPC` requests the read scopes needed by the module by default. Write-action cmdlets request additional scopes only when needed.

## First queries

```powershell
Get-CloudPC | Format-Table Name,ProvisioningStatus,AssignedUserUpn
Get-CloudPCUsage | Format-Table CloudPcName,UsageStatus,DaysSinceLastSignIn
Get-CloudPCByProvisioningPolicy | Format-Table DisplayName,ProvisioningType,CloudPCCount
```

