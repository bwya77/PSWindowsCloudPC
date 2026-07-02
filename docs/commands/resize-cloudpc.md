---
id: resize-cloudpc
title: Resize-CloudPC
description: "Resizes one or more Windows 365 Cloud PCs to a target service plan."
---

# Resize-CloudPC

Resizes one or more Windows 365 Cloud PCs to a target service plan.

## Description

Issues POST /deviceManagement/virtualEndpoint/cloudPCs/&#123;id&#125;/resize against Microsoft Graph v1.0
to upgrade or downgrade a Cloud PC to a target service plan with a different vCPU and storage
configuration. Graph returns 204 No Content when the asynchronous resize request is accepted.

When -UseMaintenanceWindow is specified, the cmdlet creates a Microsoft Graph beta
cloudPcBulkResize action instead: POST /deviceManagement/virtualEndpoint/bulkActions with
scheduledDuringMaintenanceWindow set to true. This routes one or more Cloud PCs through
assigned Cloud PC maintenance windows.

The resize action requires the CloudPC.ReadWrite.All scope. No Microsoft.Graph.DeviceManagement.Administration
module dependency is required because WindowsCloudPC sends the request through Invoke-MgGraphRequest
from Microsoft.Graph.Authentication.

The target service plan can be supplied by ID, exact display name, or a WindowsCloudPC.ServicePlan
object returned by Get-CloudPCServicePlan.

## Syntax

```powershell

Resize-CloudPC -CloudPC <Object> [-TargetServicePlanId <string>] [-TargetServicePlanName <string>] [-TargetServicePlan <ServicePlan>] [-Force] [-UseMaintenanceWindow] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

Resize-CloudPC -Id <string> [-TargetServicePlanId <string>] [-TargetServicePlanName <string>] [-TargetServicePlan <ServicePlan>] [-Force] [-UseMaintenanceWindow] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

```

## Parameters

| Name | Type | Required | Aliases | Description |
| --- | --- | --- | --- | --- |
| `CloudPC` | `Object` | Yes |  | A WindowsCloudPC.CloudPC object returned by Get-CloudPC, or an exact Cloud PC name, Cloud PC ID,<br />managed device ID, Azure AD device ID, or assigned user principal name. Accepts pipeline input. |
| `Force` | `SwitchParameter` | No |  | Suppress confirmation prompts. Equivalent to -Confirm:$false. |
| `Id` | `String` | Yes | `CloudPcId` | The Cloud PC ID when you do not have a CloudPC object available. |
| `PassThru` | `SwitchParameter` | No |  | Emit a WindowsCloudPC.ResizeResult object describing the accepted resize request. By default<br />the cmdlet is silent on success. |
| `TargetServicePlan` | `Object` | No |  | A WindowsCloudPC.ServicePlan object returned by Get-CloudPCServicePlan. |
| `TargetServicePlanId` | `String` | No | `ServicePlanId` | The target Windows 365 service plan ID. Alias: ServicePlanId. |
| `TargetServicePlanName` | `String` | No | `ServicePlanName`, `TargetSku`, `Sku` | The exact display name of the target Windows 365 service plan. The cmdlet resolves it with<br />Get-CloudPCServicePlan before sending the resize request. |
| `UseMaintenanceWindow` | `SwitchParameter` | No |  | Create a Microsoft Graph beta cloudPcBulkResize action and schedule it according to assigned<br />Cloud PC maintenance windows. Pipeline input is collected and submitted as one bulk action. |

## Output

```plaintext
CloudPcId             : 00000000-0000-0000-0000-000000000000
CloudPcName           : CPC-USER-01
TargetServicePlanId   : 30d0e128-de93-41dc-89ec-33d84bb662a0
TargetServicePlanName : Cloud PC Enterprise 4vCPU/16GB/128GB
Status                : Accepted
RequestedAt           : 7/1/2026 3:45:00 PM
ErrorMessage          :
```

Maintenance window example:

```plaintext
CloudPcId                        : 00000000-0000-0000-0000-000000000000
CloudPcName                      : CPC-USER-01
TargetServicePlanId              : 9ecf691d-8b82-46cb-b254-cd061b2c02fb
TargetServicePlanName            : 9ecf691d-8b82-46cb-b254-cd061b2c02fb
Status                           : pending
RequestedAt                      : 7/2/2026 2:50:00 PM
ErrorMessage                     :
UseMaintenanceWindow             : True
ScheduledDuringMaintenanceWindow : True
BulkActionId                     : 11111111-2222-3333-4444-555555555555
RawBulkAction                    : @{id=11111111-2222-3333-4444-555555555555; @odata.type=#microsoft.graph.cloudPcBulkResize; status=pending; scheduledDuringMaintenanceWindow=True}
```

Failure example:

```plaintext
CloudPcId             : 00000000-0000-0000-0000-000000000000
CloudPcName           : CPC-USER-01
TargetServicePlanId   : 9ecf691d-8b82-46cb-b254-cd061b2c02fb
TargetServicePlanName : 9ecf691d-8b82-46cb-b254-cd061b2c02fb
Status                : Failed
RequestedAt           : 7/1/2026 3:55:00 PM
ErrorMessage          : Response status code does not indicate success: Conflict (Conflict). {"error":{"code":"Conflict","message":"Resize is not allowed for the current Cloud PC state."}}
```

## Graph endpoints

```text
/v1.0/deviceManagement/virtualEndpoint/cloudPCs/{id}/resize
/beta/deviceManagement/virtualEndpoint/bulkActions
```

## Example 1

```powershell
Get-CloudPC -Name 'CPC-BRAD-01' |
Resize-CloudPC -TargetServicePlanName 'Cloud PC Enterprise 4vCPU/16GB/128GB' -WhatIf
```

Previews resizing a Cloud PC to a target service plan by exact display name.

## Example 2

```powershell
Resize-CloudPC -Id 'b0a9cde2-e170-4dd9-97c3-ad1d3328a711' `
-TargetServicePlanId '30d0e128-de93-41dc-89ec-33d84bb662a0' `
-Force `
-PassThru
```

Sends a resize request for a single Cloud PC by ID and emits the request result.

## Example 3

```powershell
$plan = Get-CloudPCServicePlan -DisplayName 'Cloud PC Enterprise 8vCPU/32GB/256GB'
Get-CloudPC -Type Dedicated | Resize-CloudPC -TargetServicePlan $plan -WhatIf
```

Resolves a target service plan object once, then previews resizing every dedicated Cloud PC.

## Example 4

```powershell
Resize-CloudPC -CloudPC 'CPC-ENT-0M94O' `
-ServicePlanId '9ecf691d-8b82-46cb-b254-cd061b2c02fb' `
-UseMaintenanceWindow `
-PassThru
```

Submits a single Cloud PC resize as a bulk resize action that uses assigned maintenance windows.


## Source

[View Resize-CloudPC.ps1 on GitHub](https://github.com/bwya77/PSWindowsCloudPC/blob/main/Public/Resize-CloudPC.ps1)
