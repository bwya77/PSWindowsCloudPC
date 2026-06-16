function Invoke-CloudPCReprovision {
    <#
    .SYNOPSIS
        Reprovisions one or more Windows 365 Cloud PCs.

    .DESCRIPTION
        Issues POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/reprovision against Microsoft Graph,
        which is an asynchronous operation: Graph returns 204 No Content immediately and the actual
        reprovisioning happens in the background.

        Because reprovisioning resets the Cloud PC, this cmdlet supports -WhatIf / -Confirm and defaults
        to ConfirmImpact = 'High'. Use -Force to suppress the confirmation prompt in automation.

        Requires the CloudPC.ReadWrite.All scope; the cmdlet automatically re-authenticates via
        Connect-CloudPC if the current Graph session does not already have it.

    .PARAMETER CloudPC
        A WindowsCloudPC.CloudPC object (as returned by Get-CloudPC). Accepts pipeline input.

    .PARAMETER Id
        The Cloud PC ID (GUID) when you do not have a CloudPC object handy.

    .PARAMETER OsVersion
        Optional operating system version for the reprovisioned Cloud PC: windows10 or windows11.

    .PARAMETER UserAccountType
        Optional account type for the provisioned user: standardUser or administrator.

    .PARAMETER Force
        Suppress the confirmation prompt. Equivalent to -Confirm:$false.

    .PARAMETER PassThru
        Emit a WindowsCloudPC.ReprovisionResult object describing the outcome of each reprovision request.
        By default the cmdlet is silent on success.

    .EXAMPLE
        Get-CloudPC -Type Dedicated | Invoke-CloudPCReprovision -OsVersion windows11 -UserAccountType standardUser -Force

        Reprovisions every dedicated Cloud PC in the tenant as Windows 11 with standard user rights.

    .EXAMPLE
        Invoke-CloudPCReprovision -Id '95194d88-cec5-4b65-af62-26dbd1814364' -UserAccountType administrator -PassThru

        Reprovisions a single Cloud PC by ID, prompts for confirmation, and emits the request result.

    .EXAMPLE
        Get-CloudPC | Where-Object Name -like 'CFD-brad-*' | Invoke-CloudPCReprovision -WhatIf

        Previews which Cloud PCs would be reprovisioned without sending the requests.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByObject')]
    [OutputType('WindowsCloudPC.ReprovisionResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
        [PSTypeName('WindowsCloudPC.CloudPC')]
        [object]$CloudPC,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ById')]
        [Alias('CloudPcId')]
        [string]$Id,

        [ValidateSet('windows10','windows11')]
        [string]$OsVersion,

        [ValidateSet('standardUser','administrator')]
        [string]$UserAccountType,

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
            $cloudPcId   = $CloudPC.Id
            $cloudPcName = if ($CloudPC.Name) { $CloudPC.Name } else { $CloudPC.Id }
        }
        else {
            $cloudPcId   = $Id
            $cloudPcName = $Id
        }

        if (-not $cloudPcId) {
            Write-Error "Invoke-CloudPCReprovision: Cloud PC Id is empty; nothing to reprovision."
            return
        }

        $target = "Cloud PC '$cloudPcName' ($cloudPcId)"

        if (-not $PSCmdlet.ShouldProcess($target, 'Reprovision')) { return }

        $body = [ordered]@{}
        if ($PSBoundParameters.ContainsKey('UserAccountType')) {
            $body.userAccountType = $UserAccountType
        }
        if ($PSBoundParameters.ContainsKey('OsVersion')) {
            $body.osVersion = $OsVersion
        }

        $uri          = "https://graph.microsoft.com/v1.0/deviceManagement/virtualEndpoint/cloudPCs/$cloudPcId/reprovision"
        $status       = 'Accepted'
        $errorMessage = $null

        try {
            Invoke-MgGraphRequest -Method POST -Uri $uri -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 3 -Compress) | Out-Null
            Write-Verbose "Invoke-CloudPCReprovision: reprovision accepted for $target"
        }
        catch {
            $status       = 'Failed'
            $errorMessage = $_.Exception.Message
            Write-Error -Message "Invoke-CloudPCReprovision: reprovision failed for $target -- $errorMessage" -Exception $_.Exception
        }

        if ($PassThru) {
            [pscustomobject]@{
                PSTypeName       = 'WindowsCloudPC.ReprovisionResult'
                CloudPcId        = $cloudPcId
                CloudPcName      = $cloudPcName
                Status           = $status
                RequestedAt      = [datetime]::Now
                OsVersion        = if ($PSBoundParameters.ContainsKey('OsVersion')) { $OsVersion } else { $null }
                UserAccountType  = if ($PSBoundParameters.ContainsKey('UserAccountType')) { $UserAccountType } else { $null }
                ErrorMessage     = $errorMessage
            }
        }
    }

    end { }
}
