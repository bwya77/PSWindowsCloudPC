function Get-CloudPCLaunchDetail {
    <#
    .SYNOPSIS
        Gets launch details for one or more Windows 365 Cloud PCs.

    .DESCRIPTION
        Calls the Microsoft Graph v1.0 retrieveCloudPcLaunchDetail function for a Cloud PC.
        The response includes the Cloud PC launch URL and Windows 365 Switch compatibility
        details. When a username is available, the output also includes a Windows App
        launch URI using the ms-cloudpc:connect protocol.

        Cloud PCs that are still provisioning might not have launch details yet. In that
        case, Graph can return 404 NotFound. The cmdlet emits a normal result row with
        LaunchDetailStatus = 'Unavailable' instead of writing an error.

        By default, the cmdlet queries /me/cloudPCs/{id}/retrieveCloudPcLaunchDetail. Use
        -UserId to query /users/{userId}/cloudPCs/{id}/retrieveCloudPcLaunchDetail instead.

    .PARAMETER CloudPC
        A WindowsCloudPC.CloudPC object (as returned by Get-CloudPC). Accepts pipeline input.

    .PARAMETER Id
        The Cloud PC ID (GUID) when you do not have a CloudPC object handy.

    .PARAMETER UserId
        Optional user ID or UPN for the /users/{userId}/cloudPCs/{id}/retrieveCloudPcLaunchDetail
        form. If omitted, the cmdlet uses /me/cloudPCs/{id}/retrieveCloudPcLaunchDetail.

    .EXAMPLE
        Get-CloudPCLaunchDetail -Id 'a20d556d-85f7-88cc-bb9c-08d9902bb7bb'

        Gets launch details for a Cloud PC that belongs to the signed-in user.

    .EXAMPLE
        Get-CloudPCLaunchDetail -Id 'a20d556d-85f7-88cc-bb9c-08d9902bb7bb' -UserId 'user@contoso.com'

        Gets launch details by using the /users/{userId}/cloudPCs/{id} endpoint form.

    .EXAMPLE
        Get-CloudPC | Get-CloudPCLaunchDetail | Format-Table CloudPcName,Windows365SwitchCompatible,WindowsAppLaunchUri

        Gets launch details for Cloud PCs returned by Get-CloudPC.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByObject')]
    [OutputType('WindowsCloudPC.CloudPCLaunchDetail')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
        [PSTypeName('WindowsCloudPC.CloudPC')]
        [object]$CloudPC,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ById')]
        [Alias('CloudPcId')]
        [string]$Id,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('AssignedUserUpn','UserPrincipalName')]
        [string]$UserId
    )

    begin {
        Connect-CloudPC | Out-Null
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByObject') {
            $cloudPcId   = $CloudPC.Id
            $cloudPcName = if ($CloudPC.Name) { $CloudPC.Name } else { $CloudPC.Id }
            if (-not $PSBoundParameters.ContainsKey('UserId') -and $CloudPC.AssignedUserUpn) {
                $UserId = $CloudPC.AssignedUserUpn
            }
        }
        else {
            $cloudPcId   = $Id
            $cloudPcName = $Id
        }

        if (-not $cloudPcId) {
            Write-Error "Get-CloudPCLaunchDetail: Cloud PC Id is empty; nothing to query."
            return
        }

        $escapedCloudPcId = [uri]::EscapeDataString($cloudPcId)
        $launchUsername = if ([string]::IsNullOrWhiteSpace($UserId)) { $null } else { $UserId }
        if ([string]::IsNullOrWhiteSpace($UserId)) {
            $uri = "https://graph.microsoft.com/v1.0/me/cloudPCs/$escapedCloudPcId/retrieveCloudPcLaunchDetail"
        }
        else {
            $escapedUserId = [uri]::EscapeDataString($UserId)
            $uri = "https://graph.microsoft.com/v1.0/users/$escapedUserId/cloudPCs/$escapedCloudPcId/retrieveCloudPcLaunchDetail"
        }

        try {
            $resp = Invoke-MgGraphRequest -Method GET -Uri $uri
        }
        catch {
            $errorMessage = $_.Exception.Message
            if ($errorMessage -match '\bNotFound\b|\b404\b') {
                [pscustomobject]@{
                    PSTypeName                                      = 'WindowsCloudPC.CloudPCLaunchDetail'
                    CloudPcId                                       = $cloudPcId
                    CloudPcName                                     = $cloudPcName
                    UserId                                          = if ([string]::IsNullOrWhiteSpace($UserId)) { 'me' } else { $UserId }
                    CloudPcLaunchUrl                                = $null
                    WindowsAppLaunchUri                             = $null
                    Windows365SwitchCompatible                      = $null
                    Windows365SwitchCompatibilityFailureReasonType   = $null
                    LaunchDetailStatus                              = 'Unavailable'
                    ErrorMessage                                    = $errorMessage
                    Raw                                             = $null
                }
                return
            }

            Write-Error -Message "Get-CloudPCLaunchDetail: query failed for $cloudPcName ($cloudPcId) -- $errorMessage" -Exception $_.Exception
            return
        }

        $windowsAppLaunchUri = $null
        if ($resp.cloudPcLaunchUrl -and -not [string]::IsNullOrWhiteSpace($launchUsername)) {
            $queryParts = [ordered]@{
                cpcid       = if ($resp.cloudPcId) { $resp.cloudPcId } else { $cloudPcId }
                username    = $launchUsername
                environment = 'PROD'
                source      = 'IWP'
                rdlaunchurl = $resp.cloudPcLaunchUrl
            }

            $encodedQuery = foreach ($entry in $queryParts.GetEnumerator()) {
                '{0}={1}' -f $entry.Key, [uri]::EscapeDataString([string]$entry.Value)
            }
            $windowsAppLaunchUri = 'ms-cloudpc:connect?' + ($encodedQuery -join '&')
        }

        [pscustomobject]@{
            PSTypeName                                      = 'WindowsCloudPC.CloudPCLaunchDetail'
            CloudPcId                                       = if ($resp.cloudPcId) { $resp.cloudPcId } else { $cloudPcId }
            CloudPcName                                     = $cloudPcName
            UserId                                          = if ([string]::IsNullOrWhiteSpace($UserId)) { 'me' } else { $UserId }
            CloudPcLaunchUrl                                = $resp.cloudPcLaunchUrl
            WindowsAppLaunchUri                             = $windowsAppLaunchUri
            Windows365SwitchCompatible                      = $resp.windows365SwitchCompatible
            Windows365SwitchCompatibilityFailureReasonType   = $resp.windows365SwitchCompatibilityFailureReasonType
            LaunchDetailStatus                              = 'Available'
            ErrorMessage                                    = $null
            Raw                                             = $resp
        }
    }

    end { }
}
