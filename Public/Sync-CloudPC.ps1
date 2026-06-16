function Sync-CloudPC {
    <#
    .SYNOPSIS
        Syncs one or more Windows 365 Cloud PCs through the Intune managed device action.

    .DESCRIPTION
        Issues POST /deviceManagement/managedDevices/{managedDeviceId}/syncDevice against Microsoft Graph beta,
        which asks Intune to check in the underlying managed device for a Cloud PC.

        The cmdlet accepts Cloud PC objects from Get-CloudPC, exact Cloud PC names, Cloud PC IDs,
        or managed device IDs. Use -ManagedDeviceId when you already have the Intune managedDevice ID.
        It supports -WhatIf / -Confirm and defaults to ConfirmImpact = 'Medium'. Use -Force to suppress
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
        The Intune managedDevice ID to sync directly.

    .PARAMETER Force
        Suppress the confirmation prompt. Equivalent to -Confirm:$false.

    .PARAMETER PassThru
        Emit a WindowsCloudPC.SyncResult object describing the outcome of each sync request.
        By default the cmdlet is silent on success.

    .EXAMPLE
        Sync-CloudPC -CloudPC 'CPC-brad-U2O0S' -Force -PassThru

        Resolves a Cloud PC by exact name and sends the sync request to the underlying managed device.

    .EXAMPLE
        Sync-CloudPC -Id 'f55ba1ae-4d31-4b41-a19f-5ca6fd5d8ffe' -Force -PassThru

        Resolves a Cloud PC by ID, then syncs its Intune managed device.

    .EXAMPLE
        Sync-CloudPC -ManagedDeviceId 'a11da134-b0bf-4964-9887-c0034a5cbf43' -Force -PassThru

        Sends the sync request directly to an Intune managedDevice ID.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByObject')]
    [OutputType('WindowsCloudPC.SyncResult')]
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
                Write-Error "Sync-CloudPC: Cloud PC Id '$Id' was not found. Pass a Cloud PC object from Get-CloudPC, an exact Cloud PC name, or -ManagedDeviceId."
                return
            }
            if ($cloudPcMatches.Count -gt 1) {
                Write-Error "Sync-CloudPC: Cloud PC Id '$Id' matched more than one object. Pipe the exact object from Get-CloudPC or use -ManagedDeviceId."
                return
            }

            $cloudPcId       = $cloudPcMatches[0].Id
            $cloudPcName     = if ($cloudPcMatches[0].Name) { $cloudPcMatches[0].Name } else { $cloudPcMatches[0].Id }
            $managedDeviceId = $cloudPcMatches[0].ManagedDeviceId
        }
        else {
            if ($CloudPC -is [string]) {
                if ([string]::IsNullOrWhiteSpace($CloudPC)) {
                    Write-Error "Sync-CloudPC: Cloud PC name, Cloud PC Id, or managed device Id is empty; nothing to sync."
                    return
                }

                $cloudPcMatches = @(Get-CloudPC | Where-Object { $_.Id -eq $CloudPC -or $_.Name -eq $CloudPC -or $_.ManagedDeviceId -eq $CloudPC })
                if ($cloudPcMatches.Count -eq 0) {
                    Write-Error "Sync-CloudPC: Cloud PC '$CloudPC' was not found. Pass a Cloud PC object from Get-CloudPC, an exact Cloud PC name, a Cloud PC Id, or -ManagedDeviceId."
                    return
                }
                if ($cloudPcMatches.Count -gt 1) {
                    Write-Error "Sync-CloudPC: Cloud PC '$CloudPC' matched more than one object. Pipe the exact object from Get-CloudPC or use -ManagedDeviceId."
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
            Write-Error "Sync-CloudPC: managed device Id is empty for Cloud PC '$cloudPcName'; nothing to sync."
            return
        }

        $target = "Cloud PC '$cloudPcName' managed device ($managedDeviceId)"

        if (-not $PSCmdlet.ShouldProcess($target, 'Sync managed device')) { return }

        $escapedManagedDeviceId = [uri]::EscapeDataString($managedDeviceId)
        $uri          = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$escapedManagedDeviceId/syncDevice"
        $status       = 'Accepted'
        $errorMessage = $null

        try {
            Invoke-MgGraphRequest -Method POST -Uri $uri | Out-Null
            Write-Verbose "Sync-CloudPC: sync accepted for $target"
        }
        catch {
            $status       = 'Failed'
            $errorMessage = $_.Exception.Message
            Write-Error -Message "Sync-CloudPC: sync failed for $target - $errorMessage" -Exception $_.Exception
        }

        if ($PassThru) {
            [pscustomobject]@{
                PSTypeName      = 'WindowsCloudPC.SyncResult'
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
