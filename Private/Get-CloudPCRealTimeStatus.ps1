function Get-CloudPCRealTimeStatus {
    <#
    .SYNOPSIS
        Calls the beta getRealTimeRemoteConnectionStatus report and normalizes the
        Schema/Values tabular response into a flat object.

    .DESCRIPTION
        The /reports/getRealTimeRemoteConnectionStatus(cloudPcId='...') endpoint returns
        a single-row report with columns ManagedDeviceName, CloudPcId, DaysSinceLastSignIn,
        SignInStatus, LastActiveTime. The wire format is the Cloud PC reports tabular
        shape:
            {
                "Schema": [{ "Column": "...", "PropertyType": "..." }, ... ],
                "Values": [ [ "row1col1", "row1col2", ... ] ]
            }

        This helper handles all three response shapes Invoke-MgGraphRequest may emit
        (parsed hashtable, raw bytes, or string) and returns one PSCustomObject with
        the schema columns as properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CloudPcId
    )

    if ([string]::IsNullOrWhiteSpace($CloudPcId)) { return $null }

    $escaped = [uri]::EscapeDataString($CloudPcId)
    $uri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/reports/getRealTimeRemoteConnectionStatus(cloudPcId='$escaped')"

    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
    }
    catch {
        Write-Verbose "Get-CloudPCRealTimeStatus: $CloudPcId failed ($($_.Exception.Message))"
        return $null
    }

    if (-not $response) { return $null }

    # Server sometimes returns application/octet-stream — coerce to a parsed object.
    $payload = $response
    if ($payload -is [byte[]]) {
        $payload = [System.Text.Encoding]::UTF8.GetString($payload) | ConvertFrom-Json -AsHashtable
    }
    elseif ($payload -is [string]) {
        $payload = $payload | ConvertFrom-Json -AsHashtable
    }

    if (-not $payload.Schema -or -not $payload.Values -or $payload.Values.Count -eq 0) {
        return $null
    }

    $row = $payload.Values[0]
    $bag = [ordered]@{}
    for ($i = 0; $i -lt $payload.Schema.Count; $i++) {
        $col = $payload.Schema[$i].Column
        $val = $row[$i]
        if ($col -eq 'LastActiveTime' -and $val) {
            try { $val = ([datetime]$val).ToLocalTime() } catch { Write-Verbose "Get-CloudPCRealTimeStatus: could not parse LastActiveTime '$val'" }
        }
        $bag[$col] = $val
    }
    $bag['Raw'] = $payload
    [pscustomobject]$bag
}
