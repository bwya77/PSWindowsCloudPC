---
id: connect-cloudpc
title: Connect-CloudPC
description: "Connects to Microsoft Graph with the scopes required by WindowsCloudPC."
---

# Connect-CloudPC

Connects to Microsoft Graph with the scopes required by WindowsCloudPC.

## Description

Idempotent: if an existing Graph session already covers the required scopes, no prompt
is shown. Use -Force to re-authenticate (e.g. to add scopes or switch accounts).
Connect-Windows365 is exported as an alias for this command.

## Syntax

```powershell

Connect-CloudPC [[-AdditionalScopes] <string[]>] [-Force] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `AdditionalScopes` | `String[]` | No |  | Extra Graph scopes to request on top of the module defaults. |
| `Force` | `SwitchParameter` | No |  | Disconnect any existing session and re-authenticate. |

## Graph endpoints

Endpoint details are described in the source and examples.

## Example 1

```powershell
Connect-CloudPC
```

## Example 2

```powershell
Connect-CloudPC -AdditionalScopes 'CloudPC.ReadWrite.All'
```

## Example 3

```powershell
Connect-Windows365
```


## Source

[View Connect-CloudPC.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Connect-CloudPC.ps1)
