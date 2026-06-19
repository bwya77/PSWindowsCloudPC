function Rename-CloudPC {
    <#
    .SYNOPSIS
        Renames a Windows 365 Cloud PC display name.

    .DESCRIPTION
        Calls Microsoft Graph v1.0
        https://graph.microsoft.com/v1.0/deviceManagement/virtualEndpoint/cloudPCs/{id}/rename
        to update the Cloud PC displayName.

        When ManagedDeviceName is specified, the cmdlet also calls Microsoft Graph beta
        https://graph.microsoft.com/beta/deviceManagement/managedDevices/{managedDeviceId}/setDeviceName
        to rename the linked Intune managed device.

        This is an asynchronous service action. Graph returns 204 No Content
        when the rename request is accepted. Use -WhatIf to preview the request.

        Requires the CloudPC.ReadWrite.All scope. Managed device rename also
        requires DeviceManagementManagedDevices.PrivilegedOperations.All. The
        cmdlet automatically reauthenticates via Connect-CloudPC if the current
        Graph session does not already have the required scopes.

    .PARAMETER CloudPC
        A WindowsCloudPC.CloudPC object returned by Get-CloudPC, or an exact
        Cloud PC name, Cloud PC ID, managed device ID, Azure AD device ID, or
        assigned user principal name. Accepts pipeline input.

    .PARAMETER Id
        The Cloud PC ID when you do not have a CloudPC object available.

    .PARAMETER NewDisplayName
        The new Cloud PC display name.

    .PARAMETER ManagedDeviceName
        Optional new Intune managed device name. When provided, Rename-CloudPC also
        calls the managedDevice setDeviceName action for the Cloud PC's linked
        managed device. Alias: DeviceName.

    .PARAMETER Force
        Suppress confirmation prompts. Equivalent to -Confirm:$false.

    .PARAMETER PassThru
        Emit a WindowsCloudPC.RenameResult object describing the request.

    .EXAMPLE
        Rename-CloudPC -CloudPC 'CPC-USER-01' -NewDisplayName 'Finance-CloudPC-01' -WhatIf

    .EXAMPLE
        Get-CloudPC -UserPrincipalName user@contoso.com |
            Rename-CloudPC -NewDisplayName 'User-Primary-CloudPC' -Force -PassThru

    .EXAMPLE
        Rename-CloudPC -Id '<cloud-pc-id>' -NewDisplayName 'Cloud PC-HR' -PassThru

    .EXAMPLE
        Rename-CloudPC -CloudPC 'CPC-USER-01' -NewDisplayName 'Finance-CloudPC-01' -ManagedDeviceName 'Finance-CloudPC-01' -Force -PassThru
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByObject')]
    [OutputType('WindowsCloudPC.RenameResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
        [object]$CloudPC,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ById')]
        [Alias('CloudPcId')]
        [string]$Id,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$NewDisplayName,

        [Alias('DeviceName')]
        [ValidateNotNullOrEmpty()]
        [string]$ManagedDeviceName,

        [switch]$Force,

        [switch]$PassThru
    )

    begin {
        if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = 'None'
        }

        $additionalScopes = @('CloudPC.ReadWrite.All')
        if ($PSBoundParameters.ContainsKey('ManagedDeviceName')) {
            $additionalScopes += 'DeviceManagementManagedDevices.PrivilegedOperations.All'
        }

        Connect-CloudPC -AdditionalScopes $additionalScopes | Out-Null
    }

    process {
        try {
            $targetPc = if ($PSCmdlet.ParameterSetName -eq 'ById') {
                Resolve-CloudPCTarget -Id $Id -CommandName 'Rename-CloudPC'
            }
            else {
                Resolve-CloudPCTarget -CloudPC $CloudPC -CommandName 'Rename-CloudPC'
            }
        }
        catch {
            Write-Error -ErrorRecord $_
            return
        }

        if ($ManagedDeviceName -and -not $targetPc.ManagedDeviceId) {
            try {
                $resolvedTarget = Get-CloudPC -Id $targetPc.Id
                if ($resolvedTarget) {
                    $targetPc = Resolve-CloudPCTarget -CloudPC $resolvedTarget -CommandName 'Rename-CloudPC'
                }
            }
            catch {
                Write-Verbose "Rename-CloudPC: could not resolve managed device id for '$($targetPc.Id)': $($_.Exception.Message)"
            }
        }

        if ($ManagedDeviceName -and -not $targetPc.ManagedDeviceId) {
            Write-Error "Rename-CloudPC: ManagedDeviceName was provided, but Cloud PC '$($targetPc.Name)' does not have a managed device id. Pipe a Get-CloudPC object or use a resolvable Cloud PC target."
            return
        }

        $target = "Cloud PC '$($targetPc.Name)' ($($targetPc.Id))"
        $status = 'Accepted'
        $managedDeviceRenameStatus = if ($ManagedDeviceName) { 'Pending' } else { 'NotRequested' }
        $errorMessage = $null
        $managedDeviceErrorMessage = $null
        $requestedAt = [datetime]::Now

        $actionDescription = if ($ManagedDeviceName) {
            "Rename display name to '$NewDisplayName' and managed device name to '$ManagedDeviceName'"
        }
        else {
            "Rename to '$NewDisplayName'"
        }

        if (-not $PSCmdlet.ShouldProcess($target, $actionDescription)) {
            if ($PassThru) {
                [pscustomobject]@{
                    PSTypeName                = 'WindowsCloudPC.RenameResult'
                    CloudPcId                 = $targetPc.Id
                    CloudPcName               = $targetPc.Name
                    ManagedDeviceId           = $targetPc.ManagedDeviceId
                    NewDisplayName            = $NewDisplayName
                    NewManagedDeviceName      = $ManagedDeviceName
                    Status                    = 'WhatIf'
                    ManagedDeviceRenameStatus = if ($ManagedDeviceName) { 'WhatIf' } else { 'NotRequested' }
                    RequestedAt               = $null
                    ErrorMessage              = $null
                    ManagedDeviceErrorMessage = $null
                }
            }
            return
        }

        $escapedCloudPcId = [uri]::EscapeDataString($targetPc.Id)
        $uri = "https://graph.microsoft.com/v1.0/deviceManagement/virtualEndpoint/cloudPCs/$escapedCloudPcId/rename"
        $body = @{ displayName = $NewDisplayName } | ConvertTo-Json -Depth 4

        try {
            Invoke-MgGraphRequest -Method POST -Uri $uri -Body $body -ContentType 'application/json' | Out-Null
            Write-Verbose "Rename-CloudPC: rename accepted for $target"
        }
        catch {
            $status = 'Failed'
            $errorMessage = $_.Exception.Message
            Write-Error -Message "Rename-CloudPC: rename failed for $target -- $errorMessage" -Exception $_.Exception
        }

        if ($ManagedDeviceName) {
            $managedDeviceTarget = "Cloud PC '$($targetPc.Name)' managed device ($($targetPc.ManagedDeviceId))"
            $escapedManagedDeviceId = [uri]::EscapeDataString($targetPc.ManagedDeviceId)
            $managedDeviceUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$escapedManagedDeviceId/setDeviceName"
            $managedDeviceBody = @{ deviceName = $ManagedDeviceName } | ConvertTo-Json -Depth 4

            try {
                Invoke-MgGraphRequest -Method POST -Uri $managedDeviceUri -Body $managedDeviceBody -ContentType 'application/json' | Out-Null
                $managedDeviceRenameStatus = 'Accepted'
                Write-Verbose "Rename-CloudPC: managed device rename accepted for $managedDeviceTarget"
            }
            catch {
                $managedDeviceRenameStatus = 'Failed'
                $managedDeviceErrorMessage = $_.Exception.Message
                Write-Error -Message "Rename-CloudPC: managed device rename failed for $managedDeviceTarget -- $managedDeviceErrorMessage" -Exception $_.Exception
            }
        }

        if ($PassThru) {
            [pscustomobject]@{
                PSTypeName                = 'WindowsCloudPC.RenameResult'
                CloudPcId                 = $targetPc.Id
                CloudPcName               = $targetPc.Name
                ManagedDeviceId           = $targetPc.ManagedDeviceId
                NewDisplayName            = $NewDisplayName
                NewManagedDeviceName      = $ManagedDeviceName
                Status                    = $status
                ManagedDeviceRenameStatus = $managedDeviceRenameStatus
                RequestedAt               = $requestedAt
                ErrorMessage              = $errorMessage
                ManagedDeviceErrorMessage = $managedDeviceErrorMessage
            }
        }
    }
}
