function Remove-CloudPCMaintenanceWindow {
    <#
    .SYNOPSIS
        Deletes a Windows 365 Cloud PC maintenance window.

    .DESCRIPTION
        Clears assignments, then deletes a Cloud PC maintenance window by calling Microsoft Graph beta:
        POST /deviceManagement/virtualEndpoint/maintenanceWindows/{id}/assign
        DELETE /deviceManagement/virtualEndpoint/maintenanceWindows/{id}.

        Targets can be a maintenance window ID, exact display name, or a
        WindowsCloudPC.MaintenanceWindow object from Get-CloudPCMaintenanceWindow.

    .PARAMETER Id
        The maintenance window ID.

    .PARAMETER DisplayName
        Exact display name of the maintenance window to delete. Alias: Name.

    .PARAMETER MaintenanceWindow
        A WindowsCloudPC.MaintenanceWindow object returned by Get-CloudPCMaintenanceWindow.

    .PARAMETER Force
        Suppress the confirmation prompt. Equivalent to -Confirm:$false.

    .PARAMETER PassThru
        Emit a WindowsCloudPC.MaintenanceWindowRemoveResult object describing the outcome.
        By default the cmdlet is silent on success.

    .EXAMPLE
        Remove-CloudPCMaintenanceWindow -DisplayName 'Off-Hours Window' -WhatIf

        Previews deleting a maintenance window by exact display name.

    .EXAMPLE
        Get-CloudPCMaintenanceWindow -DisplayName 'Off-Hours Window' |
            Remove-CloudPCMaintenanceWindow -Force -PassThru

        Deletes a maintenance window from the pipeline and emits the delete result.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByObject')]
    [OutputType('WindowsCloudPC.MaintenanceWindowRemoveResult')]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ById')]
        [Alias('MaintenanceWindowId')]
        [string]$Id,

        [Parameter(Mandatory, ParameterSetName = 'ByDisplayName')]
        [Alias('Name')]
        [string]$DisplayName,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
        [PSTypeName('WindowsCloudPC.MaintenanceWindow')]
        [object]$MaintenanceWindow,

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
            $windowId = $MaintenanceWindow.Id
            $windowName = if ($MaintenanceWindow.DisplayName) { $MaintenanceWindow.DisplayName } else { $MaintenanceWindow.Id }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ByDisplayName') {
            $matches = @(Get-CloudPCMaintenanceWindow -DisplayName $DisplayName)
            if ($matches.Count -eq 0) {
                Write-Error "Remove-CloudPCMaintenanceWindow: maintenance window '$DisplayName' was not found."
                return
            }
            if ($matches.Count -gt 1) {
                Write-Error "Remove-CloudPCMaintenanceWindow: maintenance window '$DisplayName' matched more than one object. Pipe the exact object from Get-CloudPCMaintenanceWindow or use -Id."
                return
            }

            $windowId = $matches[0].Id
            $windowName = $matches[0].DisplayName
        }
        else {
            $windowId = $Id
            $windowName = $Id
        }

        if ([string]::IsNullOrWhiteSpace($windowId)) {
            Write-Error 'Remove-CloudPCMaintenanceWindow: maintenance window Id is empty; nothing to delete.'
            return
        }

        $target = "Cloud PC maintenance window '$windowName' ($windowId)"
        $status = 'WhatIf'
        $errorMessage = $null

        if ($PSCmdlet.ShouldProcess($target, 'Delete maintenance window')) {
            try {
                $escapedId = [uri]::EscapeDataString($windowId)
                $assignUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/maintenanceWindows/$escapedId/assign"
                $assignBody = @{ assignments = @() } | ConvertTo-Json -Depth 5 -Compress
                Write-Verbose "Remove-CloudPCMaintenanceWindow: clearing assignments for $target"
                Invoke-MgGraphRequest -Method POST -Uri $assignUri -ContentType 'application/json' -Body $assignBody | Out-Null

                $uri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/maintenanceWindows/$escapedId"
                Invoke-MgGraphRequest -Method DELETE -Uri $uri | Out-Null
                $status = 'Deleted'
                Write-Verbose "Remove-CloudPCMaintenanceWindow: deleted $target"
            }
            catch {
                $status = 'Failed'
                $errorMessage = if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
                Write-Error -Message "Remove-CloudPCMaintenanceWindow: delete failed for $target. $errorMessage" -Exception $_.Exception
            }
        }

        if ($PassThru) {
            [pscustomobject]@{
                PSTypeName   = 'WindowsCloudPC.MaintenanceWindowRemoveResult'
                Id           = $windowId
                DisplayName  = $windowName
                Status       = $status
                RequestedAt  = [datetime]::Now
                ErrorMessage = $errorMessage
            }
        }
    }

    end { }
}
