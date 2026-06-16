---
id: examples
title: Examples
description: Common WindowsCloudPC PowerShell examples.
---

# Examples

## Find idle Cloud PCs

```powershell
Get-CloudPCUsage |
    Where-Object DaysSinceLastSignIn -ge 14 |
    Sort-Object DaysSinceLastSignIn -Descending
```

## List restore point snapshots for a user

```powershell
Get-CloudPCSnapshot -User 'user@contoso.com' -Verbose |
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

## List licensing allotments

```powershell
Get-CloudPCLicensingAllotment |
    Format-Table SkuPartNumber,AllottedUnits,ConsumedUnits,AvailableUnits
```

