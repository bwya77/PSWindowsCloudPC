function Start-CloudPC {
    <#
    .SYNOPSIS
        Powers on one or more Windows 365 Cloud PCs.

    .DESCRIPTION
        Issues POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/powerOn against Microsoft Graph beta,
        which is an asynchronous operation: Graph returns 204 No Content immediately and the actual
        power-on action happens in the background.

        The cmdlet accepts Cloud PC objects from Get-CloudPC, exact Cloud PC names, or Cloud PC IDs.
        It supports -WhatIf / -Confirm and defaults to ConfirmImpact = 'High'. Use -Force to suppress
        the confirmation prompt in automation.

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
        Emit a WindowsCloudPC.PowerOnResult object describing the outcome of each power-on request.
        By default the cmdlet is silent on success.

    .EXAMPLE
        Start-CloudPC -Id '8ab4e59b-1866-4ce9-8bc8-92856e61edf4' -Force -PassThru

        Powers on a single Cloud PC by ID without prompting and emits the request result.

    .EXAMPLE
        Start-CloudPC -CloudPC 'CPC-brad-U2O0S' -Force

        Resolves a Cloud PC by exact name and sends the power-on request.

    .EXAMPLE
        Get-CloudPC -Type Dedicated | Start-CloudPC -WhatIf

        Previews which dedicated Cloud PCs would be powered on without sending requests.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByObject')]
    [OutputType('WindowsCloudPC.PowerOnResult')]
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
                    Write-Error "Start-CloudPC: Cloud PC name or Id is empty; nothing to power on."
                    return
                }

                $cloudPcMatches = @(Get-CloudPC | Where-Object { $_.Id -eq $CloudPC -or $_.Name -eq $CloudPC })
                if ($cloudPcMatches.Count -eq 0) {
                    Write-Error "Start-CloudPC: Cloud PC '$CloudPC' was not found. Pass a Cloud PC object from Get-CloudPC, an exact Cloud PC name, or an Id."
                    return
                }
                if ($cloudPcMatches.Count -gt 1) {
                    Write-Error "Start-CloudPC: Cloud PC '$CloudPC' matched more than one object. Pipe the exact object from Get-CloudPC or use -Id."
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
            Write-Error "Start-CloudPC: Cloud PC Id is empty; nothing to power on."
            return
        }

        $target = "Cloud PC '$cloudPcName' ($cloudPcId)"

        if (-not $PSCmdlet.ShouldProcess($target, 'Power on')) { return }

        $uri          = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$cloudPcId/powerOn"
        $status       = 'Accepted'
        $errorMessage = $null

        try {
            Invoke-MgGraphRequest -Method POST -Uri $uri | Out-Null
            Write-Verbose "Start-CloudPC: power-on accepted for $target"
        }
        catch {
            $status       = 'Failed'
            $errorMessage = $_.Exception.Message
            Write-Error -Message "Start-CloudPC: power-on failed for $target - $errorMessage" -Exception $_.Exception
        }

        if ($PassThru) {
            [pscustomobject]@{
                PSTypeName   = 'WindowsCloudPC.PowerOnResult'
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

