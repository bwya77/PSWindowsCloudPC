function Get-CloudPCRemoteActionResult {
    <#
    .SYNOPSIS
        Returns the recent remote-action history (restart, reprovision, restore, etc.) for a Cloud PC.

    .DESCRIPTION
        Calls /beta/deviceManagement/virtualEndpoint/cloudPCs/{id}/retrieveCloudPCRemoteActionResults
        which returns the collection of cloudPcRemoteActionResult entries Graph has on file for the
        Cloud PC — typically the most recent occurrence of each action type with timing and status.

        Use this immediately after a Restart-CloudPC / reprovision / restore to confirm that the
        action was accepted and to watch ActionState transition from 'pending' to 'done' (or 'failed').

        Emits one WindowsCloudPC.RemoteActionResult object per (CloudPC, action) pair, sorted by
        StartDateTime descending so the most recent action is first.

    .PARAMETER CloudPC
        A WindowsCloudPC.CloudPC object (as returned by Get-CloudPC). Accepts pipeline input.

    .PARAMETER Id
        The Cloud PC ID (GUID) when you do not have a CloudPC object handy.

    .EXAMPLE
        Get-CloudPCRemoteActionResult -Id '95194d88-cec5-4b65-af62-26dbd1814364'

        Lists the recent remote-action history for a single Cloud PC.

    .EXAMPLE
        Get-CloudPC | Get-CloudPCRemoteActionResult | Format-Table CloudPcName,ActionName,ActionState,StartDateTime

        Tenant-wide snapshot of the most recent action against each Cloud PC.

    .EXAMPLE
        $pc = Get-CloudPC | Where-Object Name -eq 'CFD-brad-TUFL7'
        $pc | Restart-CloudPC -Force
        $pc | Get-CloudPCRemoteActionResult | Where-Object ActionName -eq 'Restart'

        Reboots a Cloud PC, then immediately queries its action history to confirm the request
        landed (you'll see ActionState 'pending', transitioning to 'done').
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByObject')]
    [OutputType('WindowsCloudPC.RemoteActionResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
        [PSTypeName('WindowsCloudPC.CloudPC')]
        [object]$CloudPC,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ById')]
        [Alias('CloudPcId')]
        [string]$Id
    )

    begin {
        Connect-CloudPC | Out-Null
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
            Write-Error "Get-CloudPCRemoteActionResult: Cloud PC Id is empty; nothing to query."
            return
        }

        $uri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$cloudPcId/retrieveCloudPCRemoteActionResults"

        try {
            $resp = Invoke-MgGraphRequest -Method GET -Uri $uri
        }
        catch {
            Write-Error -Message "Get-CloudPCRemoteActionResult: query failed for $cloudPcName ($cloudPcId) -- $($_.Exception.Message)" -Exception $_.Exception
            return
        }

        @($resp.value) |
            Sort-Object -Property @{ Expression = { if ($_.startDateTime) { [datetime]$_.startDateTime } else { [datetime]::MinValue } }; Descending = $true } |
            ForEach-Object {
                $entry      = $_
                $hasDowntime = $null
                if ($entry.statusDetail -and $entry.statusDetail.additionalInformation) {
                    $hd = $entry.statusDetail.additionalInformation | Where-Object { $_.name -eq 'hasDownTime' } | Select-Object -First 1
                    if ($hd) { $hasDowntime = [System.Convert]::ToBoolean($hd.value) }
                }

                [pscustomobject]@{
                    PSTypeName          = 'WindowsCloudPC.RemoteActionResult'
                    CloudPcId           = $cloudPcId
                    CloudPcName         = $cloudPcName
                    ActionName          = $entry.actionName
                    ActionState         = $entry.actionState
                    StartDateTime       = if ($entry.startDateTime)       { ([datetime]$entry.startDateTime).ToLocalTime() }       else { $null }
                    LastUpdatedDateTime = if ($entry.lastUpdatedDateTime) { ([datetime]$entry.lastUpdatedDateTime).ToLocalTime() } else { $null }
                    ManagedDeviceId     = $entry.managedDeviceId
                    StatusCode          = if ($entry.statusDetail) { $entry.statusDetail.code }    else { $null }
                    StatusMessage       = if ($entry.statusDetail) { $entry.statusDetail.message } else { $null }
                    HasDownTime         = $hasDowntime
                    Raw                 = $entry
                }
            }
    }

    end { }
}
