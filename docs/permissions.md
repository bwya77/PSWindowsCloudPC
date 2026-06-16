---
id: permissions
title: Permissions
description: Microsoft Graph permissions used by WindowsCloudPC.
---

# Permissions

WindowsCloudPC uses delegated Microsoft Graph scopes and asks for additional scopes only when a command needs them.

## Default scopes

- `CloudPC.Read.All`
- `DeviceManagementManagedDevices.Read.All`
- `User.Read.All`
- `Group.Read.All`

## On-demand scopes

| Scope | Used by |
| --- | --- |
| `CloudPC.ReadWrite.All` | `Restart-CloudPC`, `Invoke-CloudPCReprovision`, `Invoke-CloudPCPolicyReprovision`, `New-CloudPCSnapshot` |
| `CloudLicensing.Read` | `Get-CloudPCLicensingAllotment` |

