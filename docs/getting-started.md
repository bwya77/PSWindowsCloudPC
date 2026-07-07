---
id: getting-started
title: Getting started
description: Install and start using the WindowsCloudPC PowerShell module.
---

# Getting started

## Requirements

- PowerShell 7 or Windows PowerShell 5.1.
- Microsoft Graph PowerShell authentication through `Connect-MgGraph`.
- A Microsoft Entra account with permissions to read or operate Windows 365 Cloud PCs.

## Install from the PowerShell Gallery

```powershell
Install-Module WindowsCloudPC -Scope CurrentUser
```

Update an existing install with:

```powershell
Update-Module WindowsCloudPC
```

## Use the latest source build

```powershell
git clone https://github.com/bwya77/PSWindowsCloudPC.git
Import-Module .\PSWindowsCloudPC\WindowsCloudPC.psd1 -Force
```

## Connect to Microsoft Graph

```powershell
Connect-CloudPC
# or
Connect-Windows365
```

`Connect-CloudPC` and its `Connect-Windows365` alias request the read scopes used across the module. Commands that perform write actions, such as restart, reprovision, and snapshot creation, request `CloudPC.ReadWrite.All` only when needed.

If you already connected to Microsoft Graph in the same session, the module reuses that connection when the required scopes are present.

## First useful queries

```powershell
Get-CloudPC | Format-Table Name,ProvisioningStatus,AssignedUserUpn
Get-CloudPCUsage | Format-Table CloudPcName,UsageStatus,DaysSinceLastSignIn
Get-CloudPCByProvisioningPolicy | Format-Table DisplayName,ProvisioningType,CloudPCCount
```

## First write operation

Use `-WhatIf` before running fleet-impacting commands.

```powershell
Get-CloudPC -UserPrincipalName user@contoso.com |
    Restart-CloudPC -WhatIf
```

When the preview looks correct:

```powershell
Get-CloudPC -UserPrincipalName user@contoso.com |
    Restart-CloudPC -Force
```

## Output style

Commands return PowerShell objects, not formatted strings. That means you can pipe results into `Where-Object`, `Sort-Object`, `Export-Csv`, `Format-Table`, or other automation.

```powershell
Get-CloudPCUsage |
    Where-Object UsageStatus -eq 'Idle' |
    Sort-Object DaysSinceLastSignIn -Descending |
    Export-Csv .\idle-cloudpcs.csv -NoTypeInformation
```
