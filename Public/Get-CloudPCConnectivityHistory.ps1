function Get-CloudPCConnectivityHistory {
    <#
    .SYNOPSIS
        Gets connectivity history for one or more Windows 365 Cloud PCs.

    .DESCRIPTION
        Calls the Microsoft Graph beta
        /deviceManagement/virtualEndpoint/cloudPCs/{id}/getCloudPcConnectivityHistory
        endpoint and normalizes the returned cloudPcConnectivityEvent collection.

        The cmdlet accepts Cloud PC IDs directly or WindowsCloudPC.CloudPC objects
        from Get-CloudPC. It emits one WindowsCloudPC.CloudPCConnectivityEvent
        object per returned event.

    .PARAMETER CloudPC
        Cloud PC objects from Get-CloudPC. Pipeline input is supported.

    .PARAMETER CloudPcId
        One or more Cloud PC IDs.

    .EXAMPLE
        Get-CloudPCConnectivityHistory -CloudPcId 'f55ba1ae-4d31-4b41-a19f-5ca6fd5d8ffe'

    .EXAMPLE
        Get-CloudPC -Type Dedicated | Get-CloudPCConnectivityHistory |
            Sort-Object EventDateTime -Descending |
            Format-Table CloudPcName,EventDateTime,EventType,EventName,EventResult
    #>
    [CmdletBinding(DefaultParameterSetName = 'ById')]
    [OutputType('WindowsCloudPC.CloudPCConnectivityEvent')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByCloudPC')]
        [PSTypeName('WindowsCloudPC.CloudPC')]
        [psobject[]]$CloudPC,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string[]]$CloudPcId
    )

    begin {
        Connect-CloudPC | Out-Null
    }

    process {
        $targets = if ($PSCmdlet.ParameterSetName -eq 'ByCloudPC') {
            foreach ($pc in $CloudPC) {
                [pscustomobject]@{
                    Id   = $pc.Id
                    Name = $pc.Name
                }
            }
        }
        else {
            foreach ($id in $CloudPcId) {
                [pscustomobject]@{
                    Id   = $id
                    Name = $null
                }
            }
        }

        foreach ($target in $targets) {
            if ([string]::IsNullOrWhiteSpace($target.Id)) {
                Write-Verbose 'Get-CloudPCConnectivityHistory: skipping target without a Cloud PC id.'
                continue
            }

            $escapedId = [uri]::EscapeDataString($target.Id)
            $uri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$escapedId/getCloudPcConnectivityHistory"

            try {
                Invoke-GraphPaged -Uri $uri | ForEach-Object {
                    $eventDateTime = $null
                    if ($_.eventDateTime) {
                        try { $eventDateTime = ([datetime]$_.eventDateTime).ToLocalTime() }
                        catch { Write-Verbose "Get-CloudPCConnectivityHistory: could not parse eventDateTime '$($_.eventDateTime)'" }
                    }

                    [pscustomobject]@{
                        PSTypeName    = 'WindowsCloudPC.CloudPCConnectivityEvent'
                        CloudPcId     = $target.Id
                        CloudPcName   = $target.Name
                        ActivityId    = $_.activityId
                        EventDateTime = $eventDateTime
                        EventType     = $_.eventType
                        EventName     = $_.eventName
                        EventResult   = $_.eventResult
                        Message       = $_.message
                        Raw           = $_
                    }
                }
            }
            catch {
                Write-Verbose "Get-CloudPCConnectivityHistory: $($target.Id) failed ($($_.Exception.Message))"
            }
        }
    }

    end { }
}
