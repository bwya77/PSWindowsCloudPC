---
id: permissions
title: Permissions
description: Microsoft Graph permissions used by WindowsCloudPC.
---

# Permissions

WindowsCloudPC uses delegated Microsoft Graph scopes. `Connect-CloudPC` handles the read scopes most commands need, and write-action commands request additional scopes only when required.

## Default scopes

- `CloudPC.Read.All`
- `DeviceManagementManagedDevices.Read.All`
- `User.Read.All`
- `Group.Read.All`

These cover Cloud PC inventory, assigned users, provisioning policies, groups, regions, settings, usage reporting, launch details, snapshots, and remote action history.

## On-demand scopes

| Scope | Used by |
| --- | --- |
| `CloudPC.ReadWrite.All` | `Restart-CloudPC`, `Invoke-CloudPCReprovision`, `Invoke-CloudPCPolicyReprovision`, `New-CloudPCSnapshot` |
| `CloudLicensing.Read` | `Get-CloudPCLicensingAllotment` |

## Command scope guide

| Area | Commands | Typical scopes |
| --- | --- | --- |
| Connect | `Connect-CloudPC` | Read scopes listed above |
| Inventory | `Get-CloudPC`, `Get-CloudPCByProvisioningPolicy`, `Get-CloudPCProvisioningPolicy`, `Get-CloudPCSupportedRegion`, `Get-CloudPCSettingProfile`, `Get-CloudPCUserSetting` | `CloudPC.Read.All`, plus user and group read scopes |
| Usage and actions | `Get-CloudPCUsage`, `Get-CloudPCLaunchDetail`, `Get-CloudPCRemoteActionResult` | `CloudPC.Read.All`, `DeviceManagementManagedDevices.Read.All` |
| Snapshots | `Get-CloudPCSnapshot`, `New-CloudPCSnapshot` | Read for viewing, `CloudPC.ReadWrite.All` for creating |
| Reprovisioning and restart | `Restart-CloudPC`, `Invoke-CloudPCReprovision`, `Invoke-CloudPCPolicyReprovision` | `CloudPC.ReadWrite.All` |
| Licensing | `Get-CloudPCLicensingAllotment` | `CloudLicensing.Read` |

## Admin consent

Some tenants require administrator consent before delegated Graph scopes can be used. If a command fails with a consent error, have an administrator approve the requested scopes for the Microsoft Graph PowerShell application or connect with an account that can grant consent.

## Least privilege notes

- Read-only inventory commands do not require `CloudPC.ReadWrite.All`.
- Write commands support `-WhatIf` where practical so you can preview targets before making a change.
- Fleet-wide commands should be paired with filters, policy IDs, user scoping, or explicit exclusions when possible.
