function Get-CloudPCUsageBeta {
    <#
    .SYNOPSIS
        Experimental sibling of Get-CloudPCUsage that uses the real-time remote connection
        status report for a definitive "is anyone connected right now" signal.

    .DESCRIPTION
        Hits the beta /reports/getRealTimeRemoteConnectionStatus(cloudPcId='...') endpoint
        per Cloud PC and maps SignInStatus -> UsageStatus:

            SignedIn     -> inUse
            NotSignedIn  -> available
            (anything else passes through verbatim)

        This is more reliable than Get-CloudPCUsage for dedicated PCs because it reflects
        the actual current RDP/HTTPS session, not cached managedDevice logon history.
        Also exposes DaysSinceLastSignIn and LastActiveTime so you can find genuinely
        idle Cloud PCs (e.g. candidates for reclamation).

        Marked "Beta" because the report endpoint is on Graph beta and the response
        format can change without notice. Once stable this will fold into Get-CloudPCUsage.

    .PARAMETER CloudPC
        Pipe in objects from Get-CloudPC to enrich a pre-filtered set instead of re-querying.

    .PARAMETER ProvisioningPolicyId
        Limit the report to a single provisioning policy.

    .PARAMETER Type
        Shared, Dedicated, or All (default).

    .EXAMPLE
        Get-CloudPCUsageBeta | Format-Table CloudPcName,UsageStatus,SignInStatus,DaysSinceLastSignIn,LastActiveTime

    .EXAMPLE
        # Cloud PCs nobody has touched in 30 days
        Get-CloudPCUsageBeta | Where-Object DaysSinceLastSignIn -ge 30

    .EXAMPLE
        # Combine with a policy filter
        Get-CloudPCProvisioningPolicy -Name 'W365-Flex-Dedicated' | Get-CloudPC | Get-CloudPCUsageBeta
    #>
    [CmdletBinding()]
    [OutputType('WindowsCloudPC.CloudPCUsageBeta')]
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
            $rt = $null
            if ($pc.Id) {
                $rt = Get-CloudPCRealTimeStatus -CloudPcId $pc.Id
            }

            $signInStatus = if ($rt) { $rt.SignInStatus } else { $null }
            $usageStatus  = switch ($signInStatus) {
                'SignedIn'    { 'inUse' }
                'NotSignedIn' { 'available' }
                default {
                    if ($signInStatus) { $signInStatus }
                    elseif ($pc.ConnectivityStatus) { $pc.ConnectivityStatus }
                    else { 'unknown' }
                }
            }

            [pscustomobject]@{
                PSTypeName             = 'WindowsCloudPC.CloudPCUsageBeta'
                CloudPcName            = $pc.Name
                ProvisioningType       = $pc.ProvisioningType
                ProvisioningPolicyName = $pc.ProvisioningPolicyName
                ProvisioningStatus     = $pc.ProvisioningStatus
                UsageStatus            = $usageStatus
                SignInStatus           = $signInStatus
                DaysSinceLastSignIn    = if ($rt) { $rt.DaysSinceLastSignIn } else { $null }
                LastActiveTime         = if ($rt) { $rt.LastActiveTime } else { $null }
                AssignedUserUpn        = $pc.AssignedUserUpn
                ManagedDeviceName      = if ($rt) { $rt.ManagedDeviceName } else { $null }
                CloudPcId              = $pc.Id
                ManagedDeviceId        = $pc.ManagedDeviceId
                Raw                    = if ($rt) { $rt.Raw } else { $null }
            }
        }
    }
}
