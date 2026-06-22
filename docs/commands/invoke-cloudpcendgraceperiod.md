---
id: invoke-cloudpcendgraceperiod
title: Invoke-CloudPCEndGracePeriod
description: "Ends the grace period for one or more Windows 365 Cloud PCs."
---

# Invoke-CloudPCEndGracePeriod

Ends the grace period for one or more Windows 365 Cloud PCs.

## Description

Calls Microsoft Graph beta
https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/&#123;id&#125;/endGracePeriod
to end the grace period for a Cloud PC.

Ending grace period immediately deprovisions the Cloud PC without waiting
the seven-day grace period. Use Get-CloudPC -ProvisioningStatus inGracePeriod
to review targets before invoking this action.

The service processes this action asynchronously. After Graph accepts the
request, the Cloud PC can continue to appear as inGracePeriod for several
minutes while Windows 365 state converges. Use -Wait to poll until the
Cloud PC leaves inGracePeriod or the timeout is reached.

## Syntax

```powershell

Invoke-CloudPCEndGracePeriod -CloudPC <Object> [-Force] [-Wait] [-PollIntervalSeconds <int>] [-TimeoutSeconds <int>] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

Invoke-CloudPCEndGracePeriod -Id <string> [-Force] [-Wait] [-PollIntervalSeconds <int>] [-TimeoutSeconds <int>] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

Invoke-CloudPCEndGracePeriod -All [-Force] [-Wait] [-PollIntervalSeconds <int>] [-TimeoutSeconds <int>] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `All` | `SwitchParameter` | Yes |  | Ends grace period for every Cloud PC returned by Get-CloudPC -ProvisioningStatus inGracePeriod. |
| `CloudPC` | `Object` | Yes |  | A WindowsCloudPC.CloudPC object returned by Get-CloudPC, or an exact Cloud PC identifier. |
| `Force` | `SwitchParameter` | No |  | Suppress confirmation prompts. Equivalent to -Confirm:$false. |
| `Id` | `String` | Yes | `CloudPcId` | The Cloud PC ID. |
| `PassThru` | `SwitchParameter` | No |  | Emit a WindowsCloudPC.EndGracePeriodResult object for each target. |
| `PollIntervalSeconds` | `Int32` | No |  | Seconds between wait checks. Defaults to 30. |
| `TimeoutSeconds` | `Int32` | No |  | Maximum seconds to wait. Defaults to 600. |
| `Wait` | `SwitchParameter` | No |  | Poll after a successful request until the Cloud PC leaves inGracePeriod,<br />is no longer returned, or TimeoutSeconds is reached. |

## Output

```plaintext
CloudPcId                      : 00000000-0000-0000-0000-000000000000
CloudPcName                    : CPC-GRACE-01
Status                         : Accepted
RequestedAt                    : 6/19/2026 3:30:00 PM
CompletedAt                    :
WaitRequested                  : False
WaitTimedOut                   : False
LastObservedProvisioningStatus : inGracePeriod
ExpectedStateLag               : 5-10 minutes
VerificationCommand            : Get-CloudPC -ProvisioningStatus inGracePeriod,deprovisioning | Where-Object Id -eq '00000000-0000-0000-0000-000000000000'
ErrorMessage                   :
```

## Graph endpoints

```text
/beta/deviceManagement/virtualEndpoint/cloudPCs/{id}/endGracePeriod
```

## Example 1

```powershell
Get-CloudPC -ProvisioningStatus inGracePeriod
```

## Example 2

```powershell
Invoke-CloudPCEndGracePeriod -CloudPC 'CPC-USER-01' -WhatIf
```

## Example 3

```powershell
Invoke-CloudPCEndGracePeriod -All -WhatIf
```

## Example 4

```powershell
Invoke-CloudPCEndGracePeriod -CloudPC 'CPC-USER-01' -Force -PassThru -Wait
```


## Source

[View Invoke-CloudPCEndGracePeriod.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Invoke-CloudPCEndGracePeriod.ps1)
