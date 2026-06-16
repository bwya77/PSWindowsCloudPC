---
id: reprovisioning
title: Reprovisioning
description: Reprovision individual Cloud PCs or policy-scoped Cloud PCs.
---

# Reprovisioning

Reprovisioning is destructive for the target Cloud PC. Always preview the target set first and use explicit exclusions when running against a policy or tenant-sized group.

:::warning
Reprovisioning rebuilds the Cloud PC. Confirm user impact, backup expectations, and maintenance windows before using these commands in production.
:::

## Reprovision one Cloud PC

```powershell
Get-CloudPC -UserPrincipalName user@contoso.com |
    Invoke-CloudPCReprovision -OsVersion windows11 -UserAccountType standardUser -WhatIf
```

When the target is correct:

```powershell
Get-CloudPC -UserPrincipalName user@contoso.com |
    Invoke-CloudPCReprovision -OsVersion windows11 -UserAccountType standardUser -Force
```

## Reprovision by provisioning policy

Use the policy command when you need to reapply or rebuild the Cloud PCs associated with one provisioning policy.

```powershell
Invoke-CloudPCPolicyReprovision -ProvisioningPolicyId '<policy-id>' `
    -OsVersion windows11 `
    -UserAccountType standardUser `
    -WhatIf
```

Exclude individual Cloud PCs, users, or IDs:

```powershell
Invoke-CloudPCPolicyReprovision -ProvisioningPolicyId '<policy-id>' `
    -ExcludeCloudPC 'CPC-KEEP-01','vip.user@contoso.com','<cloud-pc-id>' `
    -OsVersion windows11 `
    -UserAccountType standardUser `
    -Force
```

## Validate after reprovisioning

Check recent remote action results:

```powershell
Get-CloudPC -ProvisioningPolicyId '<policy-id>' |
    ForEach-Object {
        Get-CloudPCRemoteActionResult -CloudPC $_.Id |
            Select-Object @{Name='CloudPcName';Expression={$_.CloudPcName}},ActionName,ActionState,StartDateTime
    }
```

Then refresh inventory:

```powershell
Get-CloudPC -ProvisioningPolicyId '<policy-id>' |
    Format-Table Name,ProvisioningStatus,AssignedUserUpn
```

