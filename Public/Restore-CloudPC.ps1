function Restore-CloudPC {
    <#
    .SYNOPSIS
        Restores a Windows 365 Cloud PC from a restore point snapshot.

    .DESCRIPTION
        Calls Microsoft Graph v1.0
        https://graph.microsoft.com/v1.0/deviceManagement/virtualEndpoint/cloudPCs/{id}/restore
        to restore a Cloud PC from a snapshot ID.

        This is a destructive asynchronous service action. Graph returns
        204 No Content when the restore request is accepted. Use -WhatIf to
        preview the request before restoring a device.

        Requires the CloudPC.ReadWrite.All scope; the cmdlet automatically
        reauthenticates via Connect-CloudPC if the current Graph session does
        not already have it.

    .PARAMETER CloudPC
        A WindowsCloudPC.CloudPC object returned by Get-CloudPC, or an exact
        Cloud PC name, Cloud PC ID, managed device ID, Azure AD device ID, or
        assigned user principal name. Accepts pipeline input.

    .PARAMETER Id
        The Cloud PC ID when you do not have a CloudPC object available.

    .PARAMETER Snapshot
        A WindowsCloudPC.Snapshot object returned by Get-CloudPCSnapshot.
        The CloudPcId and SnapshotId properties are used for the restore request.

    .PARAMETER SnapshotId
        The snapshot ID to restore from when the Cloud PC is supplied separately.

    .PARAMETER Force
        Suppress confirmation prompts. Equivalent to -Confirm:$false.

    .PARAMETER PassThru
        Emit a WindowsCloudPC.RestoreResult object describing the request.

    .EXAMPLE
        Get-CloudPCSnapshot -CloudPC 'CPC-USER-01' |
            Select-Object -First 1 |
            Restore-CloudPC -WhatIf

    .EXAMPLE
        Restore-CloudPC -CloudPC 'CPC-USER-01' -SnapshotId '<snapshot-id>' -Force -PassThru

    .EXAMPLE
        Restore-CloudPC -Id '<cloud-pc-id>' -SnapshotId '<snapshot-id>' -PassThru
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByObject')]
    [OutputType('WindowsCloudPC.RestoreResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
        [object]$CloudPC,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ById')]
        [Alias('CloudPcId')]
        [string]$Id,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'BySnapshot')]
        [object]$Snapshot,

        [Parameter(Mandatory, ParameterSetName = 'ByObject')]
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [ValidateNotNullOrEmpty()]
        [string]$SnapshotId,

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
        if ($PSCmdlet.ParameterSetName -eq 'BySnapshot') {
            if (-not $Snapshot.CloudPcId -or -not $Snapshot.SnapshotId) {
                Write-Error "Restore-CloudPC: Snapshot input must include CloudPcId and SnapshotId properties."
                return
            }

            $targetPc = [pscustomobject]@{
                PSTypeName = 'WindowsCloudPC.CloudPCTarget'
                Id         = $Snapshot.CloudPcId
                Name       = if ($Snapshot.CloudPcName) { $Snapshot.CloudPcName } else { $Snapshot.CloudPcId }
            }
            $snapshotIdToRestore = $Snapshot.SnapshotId
        }
        else {
            try {
                $targetPc = if ($PSCmdlet.ParameterSetName -eq 'ById') {
                    Resolve-CloudPCTarget -Id $Id -CommandName 'Restore-CloudPC'
                }
                else {
                    Resolve-CloudPCTarget -CloudPC $CloudPC -CommandName 'Restore-CloudPC'
                }
            }
            catch {
                Write-Error -ErrorRecord $_
                return
            }

            $snapshotIdToRestore = $SnapshotId
        }

        if ([string]::IsNullOrWhiteSpace($snapshotIdToRestore)) {
            Write-Error "Restore-CloudPC: SnapshotId is empty."
            return
        }

        $target = "Cloud PC '$($targetPc.Name)' ($($targetPc.Id))"
        $status = 'Accepted'
        $errorMessage = $null
        $requestedAt = [datetime]::Now

        if (-not $PSCmdlet.ShouldProcess($target, "Restore from snapshot '$snapshotIdToRestore'")) {
            if ($PassThru) {
                [pscustomobject]@{
                    PSTypeName   = 'WindowsCloudPC.RestoreResult'
                    CloudPcId    = $targetPc.Id
                    CloudPcName  = $targetPc.Name
                    SnapshotId   = $snapshotIdToRestore
                    Status       = 'WhatIf'
                    RequestedAt  = $null
                    ErrorMessage = $null
                }
            }
            return
        }

        $escapedCloudPcId = [uri]::EscapeDataString($targetPc.Id)
        $uri = "https://graph.microsoft.com/v1.0/deviceManagement/virtualEndpoint/cloudPCs/$escapedCloudPcId/restore"
        $body = @{ cloudPcSnapshotId = $snapshotIdToRestore } | ConvertTo-Json -Depth 4

        try {
            Invoke-MgGraphRequest -Method POST -Uri $uri -Body $body -ContentType 'application/json' | Out-Null
            Write-Verbose "Restore-CloudPC: restore accepted for $target"
        }
        catch {
            $status = 'Failed'
            $errorMessage = $_.Exception.Message
            Write-Error -Message "Restore-CloudPC: restore failed for $target -- $errorMessage" -Exception $_.Exception
        }

        if ($PassThru) {
            [pscustomobject]@{
                PSTypeName   = 'WindowsCloudPC.RestoreResult'
                CloudPcId    = $targetPc.Id
                CloudPcName  = $targetPc.Name
                SnapshotId   = $snapshotIdToRestore
                Status       = $status
                RequestedAt  = $requestedAt
                ErrorMessage = $errorMessage
            }
        }
    }
}
