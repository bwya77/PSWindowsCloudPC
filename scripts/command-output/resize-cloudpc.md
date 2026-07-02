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
