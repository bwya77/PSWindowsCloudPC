---
id: snapshots
title: Snapshots
description: View and create Windows 365 Cloud PC restore point snapshots.
---

# Snapshots

Snapshots are Cloud PC restore points returned by Microsoft Graph. WindowsCloudPC can list existing snapshots and request new snapshots.

:::tip
Use `Get-CloudPCSnapshot -Verbose` when testing. Verbose output shows which Cloud PCs are being resolved and queried.
:::

## List snapshots for one Cloud PC

Use an object from `Get-CloudPC`, a Cloud PC ID, or a friendly Cloud PC name.

```powershell
Get-CloudPCSnapshot -CloudPC '<cloud-pc-id>'
Get-CloudPCSnapshot -CloudPC 'CPC-NAME-01'
Get-CloudPC -UserPrincipalName user@contoso.com | Get-CloudPCSnapshot
```

## List snapshots for a user

```powershell
Get-CloudPCSnapshot -User user@contoso.com |
    Format-Table CloudPcName,Status,SnapshotType,CreatedDateTime
```

## List snapshots for every Cloud PC

```powershell
Get-CloudPCSnapshot -All -Verbose |
    Sort-Object CloudPcName,CreatedDateTime -Descending |
    Format-Table CloudPcName,AssignedUserUpn,Status,SnapshotType,CreatedDateTime
```

## Create snapshots

Create a snapshot for a single Cloud PC:

```powershell
Get-CloudPC -UserPrincipalName user@contoso.com |
    New-CloudPCSnapshot -Force
```

Create snapshots for all Cloud PCs assigned to a user:

```powershell
New-CloudPCSnapshot -User user@contoso.com -Force |
    Format-Table CloudPcName,AssignedUserUpn,Status,ErrorMessage
```

Create snapshots for a provisioning policy, excluding known devices or users:

```powershell
New-CloudPCSnapshot -ProvisioningPolicyId '<policy-id>' `
    -ExcludeCloudPC 'CPC-KEEP-01','admin@contoso.com' `
    -Force |
    Format-Table CloudPcName,AssignedUserUpn,Status,Excluded,ErrorMessage
```

Create snapshots for the full tenant:

```powershell
New-CloudPCSnapshot -All -WhatIf
```

Run without `-WhatIf` only after the target list is correct.

## Restore from a snapshot

`Restore-CloudPC` restores a Cloud PC from a restore point snapshot through Microsoft Graph v1.0. This is a destructive remote action, so preview the target with `-WhatIf` before running it.

Restore from the newest snapshot returned for a Cloud PC:

```powershell
Get-CloudPCSnapshot -CloudPC 'CPC-NAME-01' |
    Select-Object -First 1 |
    Restore-CloudPC -WhatIf
```

Restore by Cloud PC and snapshot ID:

```powershell
Restore-CloudPC -CloudPC 'CPC-NAME-01' -SnapshotId '<snapshot-id>' -Force -PassThru |
    Format-Table CloudPcName,SnapshotId,Status,ErrorMessage
```

## Result handling

Fleet commands return one row per Cloud PC. Use `Status`, `Excluded`, and `ErrorMessage` to review what happened.

```powershell
New-CloudPCSnapshot -All -Force |
    Where-Object Status -ne 'Submitted' |
    Format-Table CloudPcName,Status,ErrorMessage
```
