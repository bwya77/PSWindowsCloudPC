function Restart-CloudPC {
    <#
    .SYNOPSIS
        Reboots one or more Windows 365 Cloud PCs.

    .DESCRIPTION
        Issues POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/reboot against Microsoft Graph,
        which is an asynchronous operation: Graph returns 204 No Content immediately and the actual
        reboot happens in the background.

        Because rebooting is destructive, this cmdlet supports -WhatIf / -Confirm and defaults to
        ConfirmImpact = 'High'. Use -Force to suppress the confirmation prompt in automation.

        Requires the CloudPC.ReadWrite.All scope; the cmdlet automatically re-authenticates via
        Connect-CloudPC if the current Graph session does not already have it.

    .PARAMETER CloudPC
        A WindowsCloudPC.CloudPC object (as returned by Get-CloudPC), or a Cloud PC name or ID.
        Accepts pipeline input.

    .PARAMETER Id
        The Cloud PC ID (GUID) when you do not have a CloudPC object handy.

    .PARAMETER Force
        Suppress the confirmation prompt. Equivalent to -Confirm:$false.

    .PARAMETER PassThru
        Emit a WindowsCloudPC.RestartResult object describing the outcome of each reboot request.
        By default the cmdlet is silent on success (mirrors Restart-Computer behavior).

    .EXAMPLE
        Get-CloudPC -Type Dedicated | Restart-CloudPC -Force

        Reboots every dedicated Cloud PC in the tenant without prompting.

    .EXAMPLE
        Restart-CloudPC -Id '95194d88-cec5-4b65-af62-26dbd1814364' -PassThru

        Reboots a single Cloud PC by ID, prompts for confirmation, and emits the request result.

    .EXAMPLE
        Get-CloudPC | Where-Object Name -like 'CFD-brad-*' | Restart-CloudPC -WhatIf

        Previews which Cloud PCs would be rebooted without sending the requests.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByObject')]
    [OutputType('WindowsCloudPC.RestartResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
        [object]$CloudPC,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ById')]
        [Alias('CloudPcId')]
        [string]$Id,

        [switch]$Force,

        [switch]$PassThru
    )

    begin {
        if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = 'None'
        }
        Connect-CloudPC -AdditionalScopes 'CloudPC.ReadWrite.All' | Out-Null
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByObject') {
            if ($CloudPC -is [string]) {
                if ([string]::IsNullOrWhiteSpace($CloudPC)) {
                    Write-Error "Restart-CloudPC: Cloud PC name or Id is empty; nothing to reboot."
                    return
                }

                $cloudPcMatches = @(Get-CloudPC | Where-Object { $_.Id -eq $CloudPC -or $_.Name -eq $CloudPC })
                if ($cloudPcMatches.Count -eq 0) {
                    Write-Error "Restart-CloudPC: Cloud PC '$CloudPC' was not found. Pass a Cloud PC object from Get-CloudPC, an exact Cloud PC name, or an Id."
                    return
                }
                if ($cloudPcMatches.Count -gt 1) {
                    Write-Error "Restart-CloudPC: Cloud PC '$CloudPC' matched more than one object. Pipe the exact object from Get-CloudPC or use -Id."
                    return
                }

                $cloudPcId   = $cloudPcMatches[0].Id
                $cloudPcName = if ($cloudPcMatches[0].Name) { $cloudPcMatches[0].Name } else { $cloudPcMatches[0].Id }
            }
            else {
                $cloudPcId   = $CloudPC.Id
                $cloudPcName = if ($CloudPC.Name) { $CloudPC.Name } else { $CloudPC.Id }
            }
        }
        else {
            $cloudPcId   = $Id
            $cloudPcName = $Id
        }

        if (-not $cloudPcId) {
            Write-Error "Restart-CloudPC: Cloud PC Id is empty; nothing to reboot."
            return
        }

        $target = "Cloud PC '$cloudPcName' ($cloudPcId)"

        if (-not $PSCmdlet.ShouldProcess($target, 'Reboot')) { return }

        $uri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$cloudPcId/reboot"
        $status       = 'Accepted'
        $errorMessage = $null

        try {
            Invoke-MgGraphRequest -Method POST -Uri $uri | Out-Null
            Write-Verbose "Restart-CloudPC: reboot accepted for $target"
        }
        catch {
            $status       = 'Failed'
            $errorMessage = $_.Exception.Message
            Write-Error -Message "Restart-CloudPC: reboot failed for $target -- $errorMessage" -Exception $_.Exception
        }

        if ($PassThru) {
            [pscustomobject]@{
                PSTypeName   = 'WindowsCloudPC.RestartResult'
                CloudPcId    = $cloudPcId
                CloudPcName  = $cloudPcName
                Status       = $status
                RequestedAt  = [datetime]::Now
                ErrorMessage = $errorMessage
            }
        }
    }

    end { }
}
