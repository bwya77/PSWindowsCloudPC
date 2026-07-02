function Update-CloudPCOrganizationSetting {
    <#
    .SYNOPSIS
        Updates Windows 365 Cloud PC organization settings.

    .DESCRIPTION
        Calls Microsoft Graph beta
        https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/organizationSettings
        to update tenant-wide Cloud PC organization settings.

        Only supplied parameters are sent in the PATCH body. Use -WhatIf to
        preview changes before updating tenant defaults.

    .PARAMETER OsVersion
        Default operating system version for new Cloud PCs: windows10 or windows11.

    .PARAMETER UserAccountType
        Default user account type for new Cloud PCs: standardUser or administrator.

    .PARAMETER EnableMEMAutoEnroll
        Whether new Cloud PCs should automatically enroll in Microsoft Endpoint Manager.

    .PARAMETER EnableSingleSignOn
        Whether new Cloud PCs support single sign-on.

    .PARAMETER WindowsLanguage
        Windows language to apply while creating Cloud PCs, such as en-US.

    .PARAMETER Force
        Suppress confirmation prompts. Equivalent to -Confirm:$false.

    .PARAMETER PassThru
        Emit a WindowsCloudPC.OrganizationSettingUpdateResult object describing the request.

    .EXAMPLE
        Update-CloudPCOrganizationSetting -EnableSingleSignOn $true -WhatIf

    .EXAMPLE
        Update-CloudPCOrganizationSetting -OsVersion windows11 -UserAccountType standardUser -WindowsLanguage en-US -Force -PassThru
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType('WindowsCloudPC.OrganizationSettingUpdateResult')]
    param(
        [ValidateSet('windows10','windows11')]
        [string]$OsVersion,

        [ValidateSet('standardUser','administrator')]
        [string]$UserAccountType,

        [bool]$EnableMEMAutoEnroll,

        [bool]$EnableSingleSignOn,

        [ValidateNotNullOrEmpty()]
        [string]$WindowsLanguage,

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
        $body = [ordered]@{
            '@odata.type' = '#microsoft.graph.cloudPcOrganizationSettings'
        }

        if ($PSBoundParameters.ContainsKey('OsVersion')) {
            $body.osVersion = $OsVersion
        }
        if ($PSBoundParameters.ContainsKey('UserAccountType')) {
            $body.userAccountType = $UserAccountType
        }
        if ($PSBoundParameters.ContainsKey('EnableMEMAutoEnroll')) {
            $body.enableMEMAutoEnroll = $EnableMEMAutoEnroll
        }
        if ($PSBoundParameters.ContainsKey('EnableSingleSignOn')) {
            $body.enableSingleSignOn = $EnableSingleSignOn
        }
        if ($PSBoundParameters.ContainsKey('WindowsLanguage')) {
            $body.windowsSettings = @{
                language = $WindowsLanguage
            }
        }

        if ($body.Count -eq 1) {
            throw 'Update-CloudPCOrganizationSetting: specify at least one setting to update.'
        }

        $uri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/organizationSettings'
        $jsonBody = $body | ConvertTo-Json -Depth 8
        $status = 'Accepted'
        $errorMessage = $null
        $requestedAt = [datetime]::Now

        if (-not $PSCmdlet.ShouldProcess('Cloud PC organization settings', 'Update')) {
            if ($PassThru) {
                [pscustomobject]@{
                    PSTypeName   = 'WindowsCloudPC.OrganizationSettingUpdateResult'
                    Status       = 'WhatIf'
                    RequestedAt  = $null
                    Body         = $body
                    ErrorMessage = $null
                }
            }
            return
        }

        try {
            Invoke-MgGraphRequest -Method PATCH -Uri $uri -Body $jsonBody -ContentType 'application/json' | Out-Null
        }
        catch {
            $status = 'Failed'
            $errorMessage = $_.Exception.Message
            Write-Error -Message "Update-CloudPCOrganizationSetting: update failed - $errorMessage" -Exception $_.Exception
        }

        if ($PassThru) {
            [pscustomobject]@{
                PSTypeName   = 'WindowsCloudPC.OrganizationSettingUpdateResult'
                Status       = $status
                RequestedAt  = $requestedAt
                Body         = $body
                ErrorMessage = $errorMessage
            }
        }
    }
}
