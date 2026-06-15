function Get-CloudPCUsage {
    <#
    .SYNOPSIS
        Reports who is signed in to each Cloud PC and whether it is in use or available.

    .DESCRIPTION
        Calls the beta /reports/getRealTimeRemoteConnectionStatus(cloudPcId='...') endpoint
        per Cloud PC — the same signal the Intune admin center's "Sign in status" column
        uses — and enriches it with the current user from the matching Intune managedDevice
        (dedicated) or sharedDeviceDetail (shared).

        UsageStatus values:
            inUse         A user is currently signed in (SignInStatus = SignedIn)
            available     Reachable, nobody signed in (SignInStatus = NotSignedIn)
            unavailable   The Cloud PC service marks the PC as unreachable
            failed        Last connectivity check failed
            unknown       Neither signal returned anything (rare — usually means a brand
                          new PC whose first telemetry hasn't landed yet)

        The real-time report is the primary source of truth. If it fails (transient Graph
        error, beta endpoint hiccup, etc.) the function falls back to the cloudPC's own
        connectivityResult.status so you still get a useful value.

        CurrentUser* fields are populated independently of UsageStatus:
            Shared      From sharedDeviceDetail.assignedToUserPrincipalName.
            Dedicated   From the managedDevice's most recent usersLoggedOn entry, falling
                        back to userPrincipalName / userDisplayName on the device.

    .PARAMETER CloudPC
        Pipe in WindowsCloudPC.CloudPC objects from Get-CloudPC. Anything else fails
        parameter binding (so a typo like Get-CloudPCUsage -CloudPC 'test' errors loudly
        instead of returning blank rows).

    .PARAMETER ProvisioningPolicyId
        Limit the report to a single provisioning policy.

    .PARAMETER Type
        Shared, Dedicated, or All (default).

    .EXAMPLE
        Get-CloudPCUsage | Format-Table CloudPcName,UsageStatus,CurrentUserDisplayName,LastActiveTime

    .EXAMPLE
        # Only Cloud PCs with an active session
        Get-CloudPCUsage | Where-Object UsageStatus -eq 'inUse'

    .EXAMPLE
        # Find idle dedicated PCs (reclamation candidates)
        Get-CloudPCUsage -Type Dedicated | Where-Object DaysSinceLastSignIn -ge 30

    .EXAMPLE
        # Pre-filter then enrich
        Get-CloudPC -Type Dedicated | Get-CloudPCUsage
    #>
    [CmdletBinding()]
    [OutputType('WindowsCloudPC.CloudPCUsage')]
    param(
        [Parameter(ValueFromPipeline)]
        [PSTypeName('WindowsCloudPC.CloudPC')]
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
            # ---- UsageStatus ------------------------------------------------
            # Primary signal: real-time remote connection status report.
            $rt = if ($pc.Id) { Get-CloudPCRealTimeStatus -CloudPcId $pc.Id } else { $null }

            $signInStatus        = $null
            $daysSinceLastSignIn = $null
            $lastActiveTime      = $null

            if ($rt) {
                $signInStatus        = $rt.SignInStatus
                $daysSinceLastSignIn = $rt.DaysSinceLastSignIn
                $lastActiveTime      = $rt.LastActiveTime

                $usageStatus = switch ($signInStatus) {
                    'SignedIn'    { 'inUse' }
                    'NotSignedIn' { 'available' }
                    default       { if ($signInStatus) { $signInStatus } else { 'unknown' } }
                }
            }
            else {
                # Fallback: cloudPC's own connectivityResult.status
                $usageStatus = if ($pc.ConnectivityStatus) { $pc.ConnectivityStatus } else { 'unknown' }
            }

            # ---- CurrentUser* enrichment ------------------------------------
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
                $md = if ($pc.ManagedDeviceId) { Get-CloudPCManagedDevice -ManagedDeviceId $pc.ManagedDeviceId } else { $null }
                if ($md) {
                    $logon = $md.usersLoggedOn |
                        Sort-Object { [datetime]$_.lastLogOnDateTime } -Descending |
                        Select-Object -First 1
                    if ($logon) {
                        $u = Resolve-CloudPCUser -IdOrUpn $logon.userId
                        $currentUserUpn  = $u.Upn
                        $currentUserName = $u.DisplayName
                        $currentUserId   = $u.Id
                        $sessionStart    = ([datetime]$logon.lastLogOnDateTime).ToLocalTime()
                    }
                    else {
                        $currentUserUpn  = $md.userPrincipalName
                        $currentUserName = $md.userDisplayName
                    }
                }
                else {
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
                SignInStatus           = $signInStatus
                DaysSinceLastSignIn    = $daysSinceLastSignIn
                LastActiveTime         = $lastActiveTime
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
