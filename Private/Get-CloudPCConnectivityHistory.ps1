function Get-CloudPCConnectivityHistory {
    <#
    .SYNOPSIS
        Gets Cloud PC connectivity history events from Microsoft Graph beta.

    .DESCRIPTION
        Calls /deviceManagement/virtualEndpoint/cloudPCs/{id}/getCloudPcConnectivityHistory
        and normalizes the returned cloudPcConnectivityEvent collection.
    #>
    [CmdletBinding()]
    [OutputType('WindowsCloudPC.CloudPCConnectivityEvent')]
    param(
        [Parameter(Mandatory)]
        [string]$CloudPcId
    )

    begin { }

    process {
        if ([string]::IsNullOrWhiteSpace($CloudPcId)) {
            return
        }

        $escaped = [uri]::EscapeDataString($CloudPcId)
        $uri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$escaped/getCloudPcConnectivityHistory"

        try {
            Invoke-GraphPaged -Uri $uri | ForEach-Object {
                $eventDateTime = $null
                if ($_.eventDateTime) {
                    try { $eventDateTime = ([datetime]$_.eventDateTime).ToLocalTime() }
                    catch { Write-Verbose "Get-CloudPCConnectivityHistory: could not parse eventDateTime '$($_.eventDateTime)'" }
                }

                [pscustomobject]@{
                    PSTypeName    = 'WindowsCloudPC.CloudPCConnectivityEvent'
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
            Write-Verbose "Get-CloudPCConnectivityHistory: $CloudPcId failed ($($_.Exception.Message))"
            return
        }
    }

    end { }
}
