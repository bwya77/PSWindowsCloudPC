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

    begin { }

    process {
        if ([string]::IsNullOrWhiteSpace($CloudPcId)) {
            return
        }

        $escaped = [uri]::EscapeDataString($CloudPcId)
        $uri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/reports/getRealTimeRemoteConnectionStatus(cloudPcId='$escaped')"

        # This endpoint returns application/octet-stream, which Invoke-MgGraphRequest
        # refuses to materialize in-memory ("Please specify '-OutputFilePath' or
        # '-InferOutputFileName'"). Spool to a temp file, read, then delete.
        $tmp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "wcpc-rtrcs-$([guid]::NewGuid().ToString('N')).json")
        $payload = $null
        try {
            try {
                Invoke-MgGraphRequest -Method GET -Uri $uri -OutputFilePath $tmp -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Verbose "Get-CloudPCRealTimeStatus: $CloudPcId failed ($($_.Exception.Message))"
                return
            }

            if (-not (Test-Path -LiteralPath $tmp)) { return }
            $json = Get-Content -LiteralPath $tmp -Raw -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($json)) { return }

            try { $payload = $json | ConvertFrom-Json -AsHashtable -ErrorAction Stop }
            catch {
                Write-Verbose "Get-CloudPCRealTimeStatus: $CloudPcId returned unparseable JSON ($($_.Exception.Message))"
                return
            }
        }
        finally {
            if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
        }

        if (-not $payload -or -not $payload.Schema) { return }

        # TotalRowCount=0 / empty Values means the PC has no sign-in history yet
        # (e.g. freshly provisioned, never used). Semantically that's "not signed
        # in / available", not "unknown" — emit a synthetic row so the caller
        # doesn't have to special-case it.
        if (-not $payload.Values -or $payload.Values.Count -eq 0) {
            [pscustomobject]@{
                ManagedDeviceName   = $null
                CloudPcId           = $CloudPcId
                DaysSinceLastSignIn = $null
                SignInStatus        = 'NotSignedIn'
                LastActiveTime      = $null
                Raw                 = $payload
            }
            return
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

    end { }
}
