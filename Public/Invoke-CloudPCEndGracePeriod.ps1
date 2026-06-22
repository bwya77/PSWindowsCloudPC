function Invoke-CloudPCEndGracePeriod {
    <#
    .SYNOPSIS
        Ends the grace period for one or more Windows 365 Cloud PCs.

    .DESCRIPTION
        Calls Microsoft Graph beta
        https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/{id}/endGracePeriod
        to end the grace period for a Cloud PC.

        Ending grace period immediately deprovisions the Cloud PC without waiting
        the seven-day grace period. Use Get-CloudPC -ProvisioningStatus inGracePeriod
        to review targets before invoking this action.

        The service processes this action asynchronously. After Graph accepts the
        request, the Cloud PC can continue to appear as inGracePeriod for several
        minutes while Windows 365 state converges. Use -Wait to poll until the
        Cloud PC leaves inGracePeriod or the timeout is reached.

    .PARAMETER CloudPC
        A WindowsCloudPC.CloudPC object returned by Get-CloudPC, or an exact Cloud PC identifier.

    .PARAMETER Id
        The Cloud PC ID.

    .PARAMETER All
        Ends grace period for every Cloud PC returned by Get-CloudPC -ProvisioningStatus inGracePeriod.

    .PARAMETER Force
        Suppress confirmation prompts. Equivalent to -Confirm:$false.

    .PARAMETER Wait
        Poll after a successful request until the Cloud PC leaves inGracePeriod,
        is no longer returned, or TimeoutSeconds is reached.

    .PARAMETER PollIntervalSeconds
        Seconds between wait checks. Defaults to 30.

    .PARAMETER TimeoutSeconds
        Maximum seconds to wait. Defaults to 600.

    .PARAMETER PassThru
        Emit a WindowsCloudPC.EndGracePeriodResult object for each target.

    .EXAMPLE
        Get-CloudPC -ProvisioningStatus inGracePeriod

    .EXAMPLE
        Invoke-CloudPCEndGracePeriod -CloudPC 'CPC-USER-01' -WhatIf

    .EXAMPLE
        Invoke-CloudPCEndGracePeriod -All -WhatIf

    .EXAMPLE
        Invoke-CloudPCEndGracePeriod -CloudPC 'CPC-USER-01' -Force -PassThru -Wait
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByObject')]
    [OutputType('WindowsCloudPC.EndGracePeriodResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
        [object]$CloudPC,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ById')]
        [Alias('CloudPcId')]
        [string]$Id,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch]$All,

        [switch]$Force,

        [switch]$Wait,

        [ValidateRange(5, 3600)]
        [int]$PollIntervalSeconds = 30,

        [ValidateRange(5, 86400)]
        [int]$TimeoutSeconds = 600,

        [switch]$PassThru
    )

    begin {
        if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = 'None'
        }

        Connect-CloudPC -AdditionalScopes 'CloudPC.ReadWrite.All' | Out-Null
    }

    process {
        $targets = @()
        if ($PSCmdlet.ParameterSetName -eq 'All') {
            $targets = @(Get-CloudPC -ProvisioningStatus inGracePeriod)
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ById') {
            $targets = @(Resolve-CloudPCTarget -Id $Id -CommandName 'Invoke-CloudPCEndGracePeriod')
        }
        else {
            try {
                $targets = @(Resolve-CloudPCTarget -CloudPC $CloudPC -CommandName 'Invoke-CloudPCEndGracePeriod')
            }
            catch {
                Write-Error -ErrorRecord $_
                return
            }
        }

        if ($targets.Count -eq 0) {
            Write-Warning 'Invoke-CloudPCEndGracePeriod: no Cloud PCs in grace period were found.'
            return
        }

        foreach ($targetPc in $targets) {
            $target = "Cloud PC '$($targetPc.Name)' ($($targetPc.Id))"
            $status = 'Accepted'
            $errorMessage = $null
            $requestedAt = [datetime]::Now
            $completedAt = $null
            $lastObservedProvisioningStatus = $targetPc.ProvisioningStatus
            $waitTimedOut = $false
            $verificationCommand = "Get-CloudPC -ProvisioningStatus inGracePeriod,deprovisioning | Where-Object Id -eq '$($targetPc.Id)'"

            if (-not $PSCmdlet.ShouldProcess($target, 'End grace period and deprovision')) {
                if ($PassThru) {
                    [pscustomobject]@{
                        PSTypeName                       = 'WindowsCloudPC.EndGracePeriodResult'
                        CloudPcId                        = $targetPc.Id
                        CloudPcName                      = $targetPc.Name
                        Status                           = 'WhatIf'
                        RequestedAt                      = $null
                        CompletedAt                      = $null
                        WaitRequested                    = [bool]$Wait
                        WaitTimedOut                     = $false
                        LastObservedProvisioningStatus   = $targetPc.ProvisioningStatus
                        ExpectedStateLag                 = '5-10 minutes'
                        VerificationCommand              = $verificationCommand
                        ErrorMessage                     = $null
                    }
                }
                continue
            }

            $escapedCloudPcId = [uri]::EscapeDataString($targetPc.Id)
            $uri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$escapedCloudPcId/endGracePeriod"

            try {
                Invoke-MgGraphRequest -Method POST -Uri $uri | Out-Null
            }
            catch {
                $status = 'Failed'
                $errorMessage = $_.Exception.Message
                Write-Error -Message "Invoke-CloudPCEndGracePeriod: action failed for $target - $errorMessage" -Exception $_.Exception
            }

            if ($Wait -and $status -eq 'Accepted') {
                $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
                do {
                    try {
                        $current = Get-CloudPC -Id $targetPc.Id
                        $lastObservedProvisioningStatus = $current.ProvisioningStatus
                        if ($lastObservedProvisioningStatus -ne 'inGracePeriod') {
                            $status = 'Completed'
                            $completedAt = [datetime]::Now
                            break
                        }
                    }
                    catch {
                        $lastObservedProvisioningStatus = 'NotFound'
                        $status = 'Completed'
                        $completedAt = [datetime]::Now
                        break
                    }

                    if ((Get-Date) -ge $deadline) {
                        $waitTimedOut = $true
                        $status = 'Accepted'
                        break
                    }

                    Start-Sleep -Seconds $PollIntervalSeconds
                } while ($true)
            }

            if ($PassThru) {
                [pscustomobject]@{
                    PSTypeName                       = 'WindowsCloudPC.EndGracePeriodResult'
                    CloudPcId                        = $targetPc.Id
                    CloudPcName                      = $targetPc.Name
                    Status                           = $status
                    RequestedAt                      = $requestedAt
                    CompletedAt                      = $completedAt
                    WaitRequested                    = [bool]$Wait
                    WaitTimedOut                     = $waitTimedOut
                    LastObservedProvisioningStatus   = $lastObservedProvisioningStatus
                    ExpectedStateLag                 = '5-10 minutes'
                    VerificationCommand              = $verificationCommand
                    ErrorMessage                     = $errorMessage
                }
            }
        }
    }
}
