function Reset-CloudPCLocalAdminPassword {
    <#
    .SYNOPSIS
        Rotates the local admin password for one or more Windows 365 Cloud PCs.

    .DESCRIPTION
        Issues POST /deviceManagement/managedDevices('{managedDeviceId}')/rotateLocalAdminPassword
        against Microsoft Graph beta, which initiates a manual local admin password rotation on
        the underlying Intune managed device.

        The cmdlet accepts Cloud PC objects from Get-CloudPC, exact Cloud PC names, Cloud PC IDs,
        or managed device IDs. Use -ManagedDeviceId when you already have the Intune managedDevice ID.
        It supports -WhatIf / -Confirm and defaults to ConfirmImpact = 'High'. Use -Force to suppress
        the confirmation prompt in automation.

        Requires the DeviceManagementManagedDevices.PrivilegedOperations.All scope; the cmdlet
        automatically re-authenticates via Connect-CloudPC if the current Graph session does not
        already have it.

    .PARAMETER CloudPC
        A WindowsCloudPC.CloudPC object (as returned by Get-CloudPC), or an exact Cloud PC name,
        Cloud PC ID, or managed device ID. Accepts pipeline input.

    .PARAMETER Id
        The Cloud PC ID (GUID) when you do not have a CloudPC object handy.

    .PARAMETER ManagedDeviceId
        The Intune managedDevice ID to rotate the local admin password for directly.

    .PARAMETER Force
        Suppress the confirmation prompt. Equivalent to -Confirm:$false.

    .PARAMETER PassThru
        Emit a WindowsCloudPC.LocalAdminPasswordRotationResult object describing the outcome of each request.
        By default the cmdlet is silent on success.

    .EXAMPLE
        Reset-CloudPCLocalAdminPassword -CloudPC 'CPC-brad-U2O0S' -Force -PassThru

        Resolves a Cloud PC by exact name and rotates the local admin password for the underlying managed device.

    .EXAMPLE
        Reset-CloudPCLocalAdminPassword -Id 'f55ba1ae-4d31-4b41-a19f-5ca6fd5d8ffe' -Force -PassThru

        Resolves a Cloud PC by ID, then rotates the local admin password for its Intune managed device.

    .EXAMPLE
        Reset-CloudPCLocalAdminPassword -ManagedDeviceId 'bbfae1fc-af9b-4621-9477-454ee0afe22b' -Force -PassThru

        Sends the rotation request directly to an Intune managedDevice ID.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByObject')]
    [OutputType('WindowsCloudPC.LocalAdminPasswordRotationResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
        [object]$CloudPC,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ById')]
        [Alias('CloudPcId')]
        [string]$Id,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ByManagedDeviceId')]
        [Alias('IntuneManagedDeviceId')]
        [string]$ManagedDeviceId,

        [switch]$Force,

        [switch]$PassThru
    )

    begin {
        if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = 'None'
        }
        Connect-CloudPC -AdditionalScopes 'DeviceManagementManagedDevices.PrivilegedOperations.All' | Out-Null
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByManagedDeviceId') {
            $cloudPcId       = $null
            $cloudPcName     = $ManagedDeviceId
            $managedDeviceId = $ManagedDeviceId
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ById') {
            $cloudPcMatches = @(Get-CloudPC | Where-Object { $_.Id -eq $Id })
            if ($cloudPcMatches.Count -eq 0) {
                Write-Error "Reset-CloudPCLocalAdminPassword: Cloud PC Id '$Id' was not found. Pass a Cloud PC object from Get-CloudPC, an exact Cloud PC name, or -ManagedDeviceId."
                return
            }
            if ($cloudPcMatches.Count -gt 1) {
                Write-Error "Reset-CloudPCLocalAdminPassword: Cloud PC Id '$Id' matched more than one object. Pipe the exact object from Get-CloudPC or use -ManagedDeviceId."
                return
            }

            $cloudPcId       = $cloudPcMatches[0].Id
            $cloudPcName     = if ($cloudPcMatches[0].Name) { $cloudPcMatches[0].Name } else { $cloudPcMatches[0].Id }
            $managedDeviceId = $cloudPcMatches[0].ManagedDeviceId
        }
        else {
            if ($CloudPC -is [string]) {
                if ([string]::IsNullOrWhiteSpace($CloudPC)) {
                    Write-Error "Reset-CloudPCLocalAdminPassword: Cloud PC name, Cloud PC Id, or managed device Id is empty; nothing to rotate."
                    return
                }

                $cloudPcMatches = @(Get-CloudPC | Where-Object { $_.Id -eq $CloudPC -or $_.Name -eq $CloudPC -or $_.ManagedDeviceId -eq $CloudPC })
                if ($cloudPcMatches.Count -eq 0) {
                    Write-Error "Reset-CloudPCLocalAdminPassword: Cloud PC '$CloudPC' was not found. Pass a Cloud PC object from Get-CloudPC, an exact Cloud PC name, a Cloud PC Id, or -ManagedDeviceId."
                    return
                }
                if ($cloudPcMatches.Count -gt 1) {
                    Write-Error "Reset-CloudPCLocalAdminPassword: Cloud PC '$CloudPC' matched more than one object. Pipe the exact object from Get-CloudPC or use -ManagedDeviceId."
                    return
                }

                $cloudPcId       = $cloudPcMatches[0].Id
                $cloudPcName     = if ($cloudPcMatches[0].Name) { $cloudPcMatches[0].Name } else { $cloudPcMatches[0].Id }
                $managedDeviceId = $cloudPcMatches[0].ManagedDeviceId
            }
            else {
                $cloudPcId       = $CloudPC.Id
                $cloudPcName     = if ($CloudPC.Name) { $CloudPC.Name } else { $CloudPC.Id }
                $managedDeviceId = $CloudPC.ManagedDeviceId
            }
        }

        if (-not $managedDeviceId) {
            Write-Error "Reset-CloudPCLocalAdminPassword: managed device Id is empty for Cloud PC '$cloudPcName'; nothing to rotate."
            return
        }

        $target = "Cloud PC '$cloudPcName' managed device ($managedDeviceId)"

        if (-not $PSCmdlet.ShouldProcess($target, 'Rotate local admin password')) { return }

        $escapedManagedDeviceId = [uri]::EscapeDataString($managedDeviceId)
        $uri          = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$escapedManagedDeviceId')/rotateLocalAdminPassword"
        $status       = 'Accepted'
        $errorMessage = $null

        try {
            Invoke-MgGraphRequest -Method POST -Uri $uri | Out-Null
            Write-Verbose "Reset-CloudPCLocalAdminPassword: rotation accepted for $target"
        }
        catch {
            $status       = 'Failed'
            $errorMessage = $_.Exception.Message
            if ($_.ErrorDetails.Message) {
                $errorMessage = "$errorMessage $($_.ErrorDetails.Message)"
            }
            Write-Error -Message "Reset-CloudPCLocalAdminPassword: rotation failed for $target - $errorMessage" -Exception $_.Exception
        }

        if ($PassThru) {
            [pscustomobject]@{
                PSTypeName      = 'WindowsCloudPC.LocalAdminPasswordRotationResult'
                CloudPcId       = $cloudPcId
                CloudPcName     = $cloudPcName
                ManagedDeviceId = $managedDeviceId
                Status          = $status
                RequestedAt     = [datetime]::Now
                ErrorMessage    = $errorMessage
            }
        }
    }

    end { }
}

