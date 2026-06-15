function Get-CloudPCUsage {
    <#
    .SYNOPSIS
        Reports who is signed in to each Cloud PC and whether it is in use or available.

    .DESCRIPTION
        Combines Get-CloudPC with Intune managedDevice lookups to produce a unified usage view.

        UsageStatus values:
            inUse        A user has an active Windows session on the Cloud PC
            available    Reachable, no active session
            unavailable  Not reachable
            failed       Last connectivity check failed
            unknown      Service has not yet reported a status

        How UsageStatus is determined:
            Shared      Reads connectivityResult.status from the Cloud PC service directly.
            Dedicated   The Cloud PC service does NOT reliably flip dedicated PCs to 'inUse'
                        (it usually stays 'available' even with an active session). Instead we
                        check the matching Intune managedDevice's usersLoggedOn[] collection:
                        any entry means a user is signed in to the PC, so we report 'inUse'.
                        connectivityResult.status of 'unavailable' or 'failed' is preserved
                        as-is (an unreachable PC is unreachable regardless of cached logon).

        CurrentUser* fields:
            Shared      Populated from sharedDeviceDetail.assignedToUserPrincipalName.
            Dedicated   Populated from the managedDevice's most recent usersLoggedOn entry,
                        falling back to userPrincipalName / userDisplayName on the device.

    .PARAMETER CloudPC
        Pipe in objects from Get-CloudPC to enrich a pre-filtered set instead of re-querying.

    .PARAMETER ProvisioningPolicyId
        Limit the report to a single provisioning policy.

    .PARAMETER Type
        Shared, Dedicated, or All (default).

    .EXAMPLE
        Get-CloudPCUsage | Format-Table CloudPcName,UsageStatus,CurrentUserDisplayName,SessionStart

    .EXAMPLE
        # Only Cloud PCs with an active session
        Get-CloudPCUsage | Where-Object UsageStatus -eq 'inUse'

    .EXAMPLE
        # Pre-filter then enrich
        Get-CloudPC -Type Dedicated | Get-CloudPCUsage
    #>
    [CmdletBinding()]
    [OutputType('WindowsCloudPC.CloudPCUsage')]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject[]]$CloudPC,

        [string]$ProvisioningPolicyId,

        [ValidateSet('Shared','Dedicated','All')]
        [string]$Type = 'All'
    )

    begin {
        Connect-CloudPC | Out-Null
        $bag   = New-Object System.Collections.Generic.List[object]
        $piped = $false
    }

    process {
        if ($CloudPC) {
            $piped = $true
            foreach ($pc in $CloudPC) { $bag.Add($pc) }
        }
    }

    end {
        if (-not $piped) {
            $bag = [System.Collections.Generic.List[object]]@(
                Get-CloudPC -ProvisioningPolicyId $ProvisioningPolicyId -Type $Type
            )
        }

        foreach ($pc in $bag) {
            $connectivity    = if ($pc.ConnectivityStatus) { $pc.ConnectivityStatus } else { 'unknown' }
            $usageStatus     = $connectivity

            $currentUserUpn  = $null
            $currentUserName = $null
            $currentUserId   = $null
            $sessionStart    = $null

            if ($pc.ProvisioningType -eq 'Shared') {
                $currentUserUpn = $pc.AssignedUserUpn
                $sessionStart   = $pc.SessionStartDateTime
                if ($currentUserUpn) {
                    $u = Resolve-CloudPCUser -IdOrUpn $currentUserUpn
                    $currentUserName = $u.DisplayName
                    $currentUserId   = $u.Id
                }
            }
            else {
                # Dedicated: the Cloud PC service rarely flips these to 'inUse', so we use the
                # managedDevice's usersLoggedOn[] as the canonical "someone is signed in" signal.
                $md = if ($pc.ManagedDeviceId) { Get-CloudPCManagedDevice -ManagedDeviceId $pc.ManagedDeviceId } else { $null }
                if ($md) {
                    $logon = $md.usersLoggedOn |
                        Sort-Object { [datetime]$_.lastLogOnDateTime } -Descending |
                        Select-Object -First 1
                    if ($logon) {
                        # A user is signed in. Promote to 'inUse' unless the PC is genuinely
                        # offline ('unavailable' / 'failed'), in which case keep that honest.
                        if ($connectivity -notin @('unavailable','failed')) {
                            $usageStatus = 'inUse'
                        }

                        $u = Resolve-CloudPCUser -IdOrUpn $logon.userId
                        $currentUserUpn  = $u.Upn
                        $currentUserName = $u.DisplayName
                        $currentUserId   = $u.Id
                        $sessionStart    = ([datetime]$logon.lastLogOnDateTime).ToLocalTime()
                    }
                    else {
                        # No logon history — fall back to the dedicated user assignment.
                        $currentUserUpn  = $md.userPrincipalName
                        $currentUserName = $md.userDisplayName
                    }
                }
                else {
                    # No managedDevice yet — fall back to the cloudPC's own assignment.
                    $currentUserUpn = $pc.AssignedUserUpn
                }
            }

            [pscustomobject]@{
                PSTypeName             = 'WindowsCloudPC.CloudPCUsage'
                CloudPcName            = $pc.Name
                ProvisioningType       = $pc.ProvisioningType
                ProvisioningPolicyName = $pc.ProvisioningPolicyName
                ProvisioningStatus     = $pc.ProvisioningStatus
                UsageStatus            = $usageStatus
                AssignedUserUpn        = $pc.AssignedUserUpn
                CurrentUserUpn         = $currentUserUpn
                CurrentUserDisplayName = $currentUserName
                CurrentUserId          = $currentUserId
                SessionStart           = $sessionStart
                CloudPcId              = $pc.Id
                ManagedDeviceId        = $pc.ManagedDeviceId
            }
        }
    }
}
