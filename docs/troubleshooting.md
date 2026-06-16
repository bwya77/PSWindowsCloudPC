---
id: troubleshooting
title: Troubleshooting
description: Common WindowsCloudPC troubleshooting steps.
---

# Troubleshooting

## Confirm the module version

```powershell
Get-Module WindowsCloudPC -ListAvailable |
    Sort-Object Version -Descending |
    Select-Object -First 1 Name,Version,Path
```

If you are testing local source changes, force import the manifest from the repository:

```powershell
Import-Module C:\Git\GitHub\WindowsCloudPC\WindowsCloudPC.psd1 -Force
```

## Confirm Graph scopes

```powershell
Get-MgContext | Select-Object Account,Scopes
```

If a command reports missing permissions, reconnect:

```powershell
Disconnect-MgGraph
Connect-CloudPC
```

Write commands may request additional scopes when they run.

## Use verbose output

Most commands support `-Verbose`. Use it when a command needs to resolve a friendly Cloud PC name, user, or provisioning policy.

```powershell
Get-CloudPCSnapshot -User user@contoso.com -Verbose
New-CloudPCSnapshot -ProvisioningPolicyId '<policy-id>' -WhatIf -Verbose
```

## Preview write actions

Use `-WhatIf` before restart, reprovision, or fleet snapshot creation.

```powershell
New-CloudPCSnapshot -All -WhatIf
Invoke-CloudPCPolicyReprovision -ProvisioningPolicyId '<policy-id>' -WhatIf
```

## Check Graph beta availability

The module uses Microsoft Graph beta endpoints for Windows 365 Cloud PC operations. If a beta endpoint changes or returns an unexpected response, update the module and retry:

```powershell
Update-Module WindowsCloudPC
```

When testing from source:

```powershell
git -C C:\Git\GitHub\WindowsCloudPC pull
Import-Module C:\Git\GitHub\WindowsCloudPC\WindowsCloudPC.psd1 -Force
```

