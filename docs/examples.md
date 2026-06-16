---
id: examples
title: Examples
description: Common WindowsCloudPC PowerShell examples.
---

# Examples

These examples show common workflows. For full syntax and parameters, use the [command reference](./commands/).

## Export a Cloud PC inventory

```powershell
Get-CloudPC |
    Select-Object Name,Id,ProvisioningStatus,ProvisioningType,AssignedUserUpn,ProvisioningPolicyId |
    Export-Csv .\cloudpc-inventory.csv -NoTypeInformation
```

## Find idle Cloud PCs

```powershell
Get-CloudPCUsage |
    Where-Object DaysSinceLastSignIn -ge 14 |
    Sort-Object DaysSinceLastSignIn -Descending |
    Format-Table CloudPcName,AssignedUserUpn,UsageStatus,DaysSinceLastSignIn
```

## Show Cloud PCs by provisioning policy

```powershell
Get-CloudPCByProvisioningPolicy |
    Sort-Object DisplayName |
    Format-Table DisplayName,ProvisioningType,CloudPCCount,AssignedGroupCount
```

## Export and copy a provisioning policy

```powershell
Export-CloudPCProvisioningPolicy -Id '<policy-id>' -Path .\policy-export.json

New-CloudPCProvisioningPolicy -Path .\policy-export.json `
    -DisplayName 'Copied Policy' `
    -Assign `
    -Force
```

## Delete a copied provisioning policy

```powershell
Remove-CloudPCProvisioningPolicy -Id '<policy-id>' -WhatIf
Remove-CloudPCProvisioningPolicy -Id '<policy-id>' -Force -PassThru
```

## Review launch detail for every Cloud PC

```powershell
Get-CloudPC |
    Get-CloudPCLaunchDetail |
    Format-Table CloudPcName,UserPrincipalName,State,LastLoginDateTime
```

## List restore point snapshots for a user

```powershell
Get-CloudPCSnapshot -User 'user@contoso.com' -Verbose |
    Format-Table CloudPcName,Status,SnapshotType,CreatedDateTime
```

## List every Cloud PC and its restore points

```powershell
Get-CloudPCSnapshot -All -Verbose |
    Sort-Object CloudPcName,CreatedDateTime -Descending |
    Format-Table CloudPcName,Status,SnapshotType,CreatedDateTime
```

## Create snapshots for a provisioning policy

```powershell
New-CloudPCSnapshot -ProvisioningPolicyId '<policy-id>' `
    -ExcludeCloudPC 'CPC-KEEP-01','user4@contoso.com' `
    -Force |
    Format-Table CloudPcName,AssignedUserUpn,Status,Excluded,ErrorMessage
```

## Reprovision a policy except excluded Cloud PCs

```powershell
Invoke-CloudPCPolicyReprovision -ProvisioningPolicyId '<policy-id>' `
    -ExcludeCloudPC 'CPC-KEEP-01','CPC-KEEP-02','cpc-id-3' `
    -OsVersion windows11 -UserAccountType standardUser -Force
```

## Review recent remote action results

```powershell
Get-CloudPCRemoteActionResult -CloudPC '<cloud-pc-id>' |
    Sort-Object StartDateTime -Descending |
    Format-Table ActionName,ActionState,StartDateTime,LastUpdatedDateTime
```

## List licensing allotments

```powershell
Get-CloudPCLicensingAllotment |
    Format-Table SkuPartNumber,AllottedUnits,ConsumedUnits,AvailableUnits
```

## Find low license capacity

```powershell
Get-CloudPCLicensingAllotment |
    Where-Object AvailableUnits -lt 10 |
    Sort-Object AvailableUnits |
    Format-Table SkuPartNumber,AllottedUnits,ConsumedUnits,AvailableUnits
```
