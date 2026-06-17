function Get-CloudPCUsage {
    <#
    .SYNOPSIS
        Reports who is signed in to each Cloud PC and whether it is in use or available.

    .DESCRIPTION
        Uses the Cloud PC endpoint's connectivityResult.status for shared Cloud
        PCs because that signal updates almost immediately for shared devices.
        It still reads getCloudPcConnectivityHistory for last sign-in timestamps.
        Dedicated Cloud PCs use the beta getCloudPcConnectivityHistory endpoint
        to infer whether the most recent user connection event is an active
        connection. The result is enriched with the current user from the
        matching Intune managedDevice (dedicated) or sharedDeviceDetail (shared).

        UsageStatus values:
            inUse         A shared endpoint or dedicated connectivity event says a user is signed in
            available     Reachable, nobody signed in or assigned
            unavailable   The Cloud PC service marks the PC as unreachable
            failed        Last connectivity check failed
            unknown       Neither signal returned anything (rare — usually means a brand
                          new PC whose first telemetry hasn't landed yet)

        Source of truth by provisioning type:
            Shared      cloudPC.connectivityResult.status from the Cloud PC endpoint.
                        Connectivity history enriches LastActiveTime only.
            Dedicated   getCloudPcConnectivityHistory, then cloudPC.connectivityResult.status.

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
            $connStatus = $pc.Raw.connectivityResult.status
            $isShared = $pc.ProvisioningType -eq 'Shared'
            $signInStatus        = $null
            $daysSinceLastSignIn = $null
            $lastActiveTime      = $null

            $history = @(if ($pc.Id) { Get-CloudPCConnectivityHistory -CloudPcId $pc.Id })
            $userEvents = @(
                $history |
                    Where-Object EventType -eq 'userConnection' |
                    Sort-Object EventDateTime -Descending
            )
            $latestStart = $userEvents |
                Where-Object { $_.EventName -eq 'Connection Started' -and $_.EventResult -eq 'success' } |
                Select-Object -First 1

            if ($latestStart) {
                $lastActiveTime = $latestStart.EventDateTime
                $daysSinceLastSignIn = [math]::Max(
                    0,
                    [int][math]::Floor((New-TimeSpan -Start $latestStart.EventDateTime -End (Get-Date)).TotalDays)
                )
            }

            if ($isShared) {
                $usageStatus = if ($connStatus) { $connStatus } else { 'unknown' }
                $signInStatus = switch ($connStatus) {
                    'inUse'     { 'SignedIn' }
                    'available' { 'NotSignedIn' }
                    default     { $null }
                }
            }
            else {
                if ($latestStart) {
                    $terminalEvent = $userEvents |
                        Where-Object {
                            $_.ActivityId -eq $latestStart.ActivityId -and
                            $_.EventDateTime -gt $latestStart.EventDateTime -and
                            ($_.EventName -eq 'Connection Finished' -or $_.EventResult -eq 'failure')
                        } |
                        Select-Object -First 1

                    if (-not $terminalEvent) {
                        $signInStatus = 'SignedIn'
                        $usageStatus = 'inUse'
                    }
                    else {
                        $signInStatus = 'NotSignedIn'
                        $usageStatus = 'available'
                    }
                }
                elseif ($userEvents) {
                    $signInStatus = 'NotSignedIn'
                    $usageStatus = 'available'
                }
                else {
                    $usageStatus = if ($connStatus) { $connStatus } else { 'unknown' }
                    $signInStatus = switch ($connStatus) {
                        'inUse'     { 'SignedIn' }
                        'available' { 'NotSignedIn' }
                        default     { $null }
                    }
                }
            }

            # ---- CurrentUser* enrichment ------------------------------------
            $currentUserUpn  = $null
            $currentUserName = $null
            $currentUserId   = $null
            $sessionStart    = $null

            if ($pc.ProvisioningType -eq 'Shared') {
                $currentUserUpn = $pc.AssignedUserUpn
                $rawSessionStart = $pc.Raw.sharedDeviceDetail.sessionStartDateTime
                if ($rawSessionStart) {
                    try { $sessionStart = ([datetime]$rawSessionStart).ToLocalTime() } catch { $sessionStart = $null }
                }
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
