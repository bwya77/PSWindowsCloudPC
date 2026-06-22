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
