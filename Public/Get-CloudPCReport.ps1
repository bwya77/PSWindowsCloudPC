function Get-CloudPCReport {
    <#
    .SYNOPSIS
        Retrieves Windows 365 Cloud PC report rows from Microsoft Graph beta stream reports.

    .DESCRIPTION
        Calls the Microsoft Graph beta Cloud PC report stream actions under
        /deviceManagement/virtualEndpoint/reports and parses the downloaded
        report file into objects. Graph returns these reports as files with a
        Schema array and a Values array. The cmdlet reads each Schema column,
        converts DateTime and common numeric types, and emits one
        WindowsCloudPC.ReportRow object per row.

        The ReportName parameter accepts only cloudPcReportName enum members
        that were verified to return report streams in a live tenant. Deprecated
        reports, tenant-state-dependent reports that returned Graph 400s, and
        enum values without a callable Graph action are intentionally excluded.
        realTimeRemoteConnectionStatus is also supported because it uses the
        same Graph report stream payload shape, but is exposed as a GET function
        scoped to a Cloud PC ID instead of a POST report action.

    .PARAMETER ReportName
        The Microsoft Graph beta cloudPcReportName enum member to retrieve.

    .PARAMETER CloudPcId
        Optional Cloud PC ID used to build the required CloudPcId filter for
        reports that are scoped to one Cloud PC, such as
        remoteConnectionHistoricalReports. If Filter is also provided, the
        CloudPcId clause is combined with it. For realTimeRemoteConnectionStatus,
        this calls the report for a single Cloud PC. When omitted, the cmdlet
        retrieves all Cloud PCs and calls the report once for each Cloud PC.

    .PARAMETER ActivityId
        Optional remote connection activity ID used to build the required
        ActivityId filter for rawRemoteConnectionReports. If Filter is also
        provided, the ActivityId clause is combined with it.

    .PARAMETER Select
        Optional report columns to request. Graph returns only selected columns
        when the target report action supports select.
        For rawRemoteConnectionReports, the Graph stream uses Timestamp and
        AvailableBandwidthInMBps column names. Common aliases SignInDateTime and
        AvailableBandwidthInMbps are normalized automatically.

    .PARAMETER Filter
        Optional OData filter expression for the report action.

    .PARAMETER Search
        Optional search string for the report action.

    .PARAMETER GroupBy
        Optional report columns to group by. For Graph report actions that
        support groupBy, this usually must match Select.

    .PARAMETER OrderBy
        Optional report columns or expressions to sort by.

    .PARAMETER Skip
        Optional number of rows to skip.

    .PARAMETER Top
        Optional number of rows to return.

    .PARAMETER OutputFilePath
        Optional path where the raw Graph report file should be saved. When not
        provided, a temporary file is used and removed after parsing.

    .PARAMETER MaxRetryCount
        Maximum number of retries for Graph 429, 503, and 504 responses. The
        retry delay honors Graph Retry-After when present and otherwise uses
        exponential backoff.

    .PARAMETER InitialRetryDelaySeconds
        First retry delay used when Graph does not return a Retry-After header.

    .PARAMETER MaxRetryDelaySeconds
        Maximum retry delay used when Graph does not return a Retry-After header.

    .PARAMETER RequestDelayMilliseconds
        Optional delay between per-Cloud-PC calls for
        realTimeRemoteConnectionStatus. Use this to proactively pace large
        tenants instead of relying only on Graph throttling responses.

    .PARAMETER Raw
        Return a WindowsCloudPC.ReportPayload object containing the parsed file,
        schema, values, action name, and output file path instead of row objects.

    .EXAMPLE
        $pc = Get-CloudPC | Select-Object -First 1
        Get-CloudPCReport -ReportName remoteConnectionHistoricalReports -CloudPcId $pc.Id -Top 50 |
            Format-Table ManagedDeviceName,SignInDateTime,SignOutDateTime,UsageInHour

    .EXAMPLE
        $activity = Get-CloudPCReport -ReportName remoteConnectionHistoricalReports -CloudPcId '<cloud-pc-id>' -Top 1
        Get-CloudPCReport -ReportName rawRemoteConnectionReports -ActivityId $activity.ActivityId -Select SignInDateTime,RoundTripTimeInMs,AvailableBandwidthInMbps |
            Sort-Object Timestamp -Descending

    .EXAMPLE
        Get-CloudPCReport -ReportName realTimeRemoteConnectionStatus |
            Format-Table ManagedDeviceName,SignInStatus,DaysSinceLastSignIn,LastActiveTime

    .EXAMPLE
        Get-CloudPCReport -ReportName frontlineLicenseUsageReport -Top 100 |
            Format-Table Timestamp,DisplayName,LicenseCount,ClaimedLicenseCount

    .EXAMPLE
        Get-CloudPCReport -ReportName regionalConnectionQualityTrendReport -Top 50 |
            Format-Table GatewayRegionName,WeeklyAvgRoundTripTimeInMs,WeeklyAvgAvailableBandwidthInMbps
    #>
    [CmdletBinding()]
    [OutputType('WindowsCloudPC.ReportRow', 'WindowsCloudPC.ReportPayload')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet(
            'remoteConnectionHistoricalReports',
            'dailyAggregatedRemoteConnectionReports',
            'totalAggregatedRemoteConnectionReports',
            'noLicenseAvailableConnectivityFailureReport',
            'frontlineLicenseUsageReport',
            'frontlineLicenseUsageRealTimeReport',
            'frontlineLicenseHourlyUsageReport',
            'frontlineRealtimeUserConnectionsReport',
            'inaccessibleCloudPcReports',
            'actionStatusReport',
            'rawRemoteConnectionReports',
            'performanceTrendReport',
            'inaccessibleCloudPcTrendReport',
            'regionalConnectionQualityTrendReport',
            'regionalConnectionQualityInsightsReport',
            'bulkActionStatusReport',
            'cloudPcInsightReport',
            'regionalInaccessibleCloudPcTrendReport',
            'cloudPcUsageCategoryReport',
            'realTimeRemoteConnectionStatus'
        )]
        [string]$ReportName,

        [string]$CloudPcId,

        [string]$ActivityId,

        [Alias('Property')]
        [string[]]$Select,

        [string]$Filter,

        [string]$Search,

        [string[]]$GroupBy,

        [string[]]$OrderBy,

        [ValidateRange(0, 2147483647)]
        [int]$Skip,

        [ValidateRange(1, 2147483647)]
        [int]$Top,

        [string]$OutputFilePath,

        [ValidateRange(0, 10)]
        [int]$MaxRetryCount = 6,

        [ValidateRange(1, 3600)]
        [int]$InitialRetryDelaySeconds = 3,

        [ValidateRange(1, 3600)]
        [int]$MaxRetryDelaySeconds = 120,

        [ValidateRange(0, 60000)]
        [int]$RequestDelayMilliseconds = 0,

        [switch]$Raw
    )

    begin {
        Connect-CloudPC | Out-Null
    }

    process {
        $definition = Resolve-CloudPCReportDefinition -ReportName $ReportName
        if ($definition.UnsupportedReason) {
            throw $definition.UnsupportedReason
        }

        if ($definition.Action -eq 'getRealTimeRemoteConnectionStatus') {
            $unsupportedParameters = @(
                'ActivityId',
                'Select',
                'Filter',
                'Search',
                'GroupBy',
                'OrderBy',
                'Skip',
                'Top'
            ) | Where-Object { $PSBoundParameters.ContainsKey($_) }

            if ($unsupportedParameters) {
                throw "realTimeRemoteConnectionStatus does not support the following parameters: $($unsupportedParameters -join ', '). Use -CloudPcId to scope to one Cloud PC, or omit it to query all Cloud PCs."
            }

            if ($OutputFilePath -and -not $CloudPcId) {
                throw "realTimeRemoteConnectionStatus supports -OutputFilePath only when -CloudPcId is specified. Omit -OutputFilePath when querying all Cloud PCs."
            }

            $targets = if ($CloudPcId) {
                @([pscustomobject]@{ Id = $CloudPcId; Name = $null })
            }
            else {
                @(Get-CloudPC | ForEach-Object {
                    [pscustomobject]@{ Id = $_.Id; Name = $_.Name }
                })
            }

            foreach ($target in $targets) {
                if ([string]::IsNullOrWhiteSpace($target.Id)) {
                    continue
                }

                $escapedCloudPcId = [uri]::EscapeDataString($target.Id)
                $uri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/reports/getRealTimeRemoteConnectionStatus(cloudPcId='$escapedCloudPcId')"
                $removeOutputFile = -not $OutputFilePath
                if ($OutputFilePath) {
                    $reportPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputFilePath)
                }
                else {
                    $reportPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "windowscloudpc-report-$ReportName-$($target.Id)-$([guid]::NewGuid().ToString('N')).json")
                }

                try {
                    $parentPath = Split-Path -Path $reportPath -Parent
                    if ($parentPath -and -not (Test-Path -LiteralPath $parentPath)) {
                        New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
                    }

                    Invoke-CloudPCGraphRequestWithRetry `
                        -Method GET `
                        -Uri $uri `
                        -Headers @{ Prefer = 'include-unknown-enum-members' } `
                        -OutputFilePath $reportPath `
                        -MaxRetryCount $MaxRetryCount `
                        -InitialRetryDelaySeconds $InitialRetryDelaySeconds `
                        -MaxRetryDelaySeconds $MaxRetryDelaySeconds `
                        -ErrorAction Stop |
                        Out-Null

                    if (-not (Test-Path -LiteralPath $reportPath)) {
                        throw "Graph did not write the expected report file: $reportPath"
                    }

                    $content = Get-Content -LiteralPath $reportPath -Raw -ErrorAction Stop
                    if ([string]::IsNullOrWhiteSpace($content)) {
                        throw "Graph returned an empty report file: $reportPath"
                    }

                    $payload = $content | ConvertFrom-Json -AsHashtable -ErrorAction Stop
                    if (-not $payload.Schema) {
                        $payload['Schema'] = @(
                            @{ Column = 'ManagedDeviceName'; PropertyType = 'String' }
                            @{ Column = 'CloudPcId'; PropertyType = 'String' }
                            @{ Column = 'DaysSinceLastSignIn'; PropertyType = 'Int64' }
                            @{ Column = 'SignInStatus'; PropertyType = 'String' }
                            @{ Column = 'LastActiveTime'; PropertyType = 'DateTime' }
                        )
                    }
                    if (-not $payload.Values -or @($payload.Values).Count -eq 0) {
                        $payload['TotalRowCount'] = 1
                        $payload['Values'] = @(, @($target.Name, $target.Id, $null, 'NotSignedIn', $null))
                    }

                    if ($Raw) {
                        [pscustomobject]@{
                            PSTypeName     = 'WindowsCloudPC.ReportPayload'
                            ReportName     = $ReportName
                            Action         = $definition.Action
                            TotalRowCount  = $payload.TotalRowCount
                            Schema         = $payload.Schema
                            Values         = $payload.Values
                            OutputFilePath = $reportPath
                            Raw            = $payload
                        }
                    }
                    else {
                        $payload | ConvertFrom-CloudPCReportPayload -ReportName $ReportName -Action $definition.Action -OutputFilePath $reportPath
                    }
                }
                finally {
                    if ($removeOutputFile -and (Test-Path -LiteralPath $reportPath)) {
                        Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
                    }
                }

                if ($RequestDelayMilliseconds -gt 0) {
                    Start-Sleep -Milliseconds $RequestDelayMilliseconds
                }
            }

            return
        }

        $body = [ordered]@{}
        if ($definition.IncludeReportName) {
            $body['reportName'] = $definition.GraphReportName
        }
        $effectiveFilter = $Filter
        $includeFilter = -not [string]::IsNullOrWhiteSpace($Filter)
        if (-not $includeFilter -and $definition.PSObject.Properties.Name -contains 'DefaultFilter') {
            $effectiveFilter = $definition.DefaultFilter
            $includeFilter = $true
        }
        if ($CloudPcId) {
            $cloudPcFilter = "CloudPcId eq '$CloudPcId'"
            $effectiveFilter = if ($effectiveFilter) { "$cloudPcFilter and ($effectiveFilter)" } else { $cloudPcFilter }
            $includeFilter = $true
        }
        if ($ActivityId) {
            $activityFilter = "ActivityId eq '$ActivityId'"
            $effectiveFilter = if ($effectiveFilter) { "$activityFilter and ($effectiveFilter)" } else { $activityFilter }
            $includeFilter = $true
        }
        if (-not $includeFilter -and $definition.DefaultFilterDays) {
            $start = (Get-Date).ToUniversalTime().AddDays(-[int]$definition.DefaultFilterDays).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            $effectiveFilter = "EventDateTime gt datetime'$start'"
            $includeFilter = $true
        }

        if ($ReportName -eq 'remoteConnectionHistoricalReports' -and -not $includeFilter) {
            throw "remoteConnectionHistoricalReports requires -CloudPcId or -Filter with a CloudPcId clause, for example: Get-CloudPCReport -ReportName remoteConnectionHistoricalReports -CloudPcId '<cloud-pc-id>' -Top 10"
        }
        if ($ReportName -eq 'rawRemoteConnectionReports' -and -not $includeFilter) {
            throw "rawRemoteConnectionReports requires -ActivityId or -Filter with an ActivityId clause. Get an ActivityId from remoteConnectionHistoricalReports first, then run: Get-CloudPCReport -ReportName rawRemoteConnectionReports -ActivityId '<activity-id>' -Top 10"
        }
        if ($includeFilter) {
            $body['filter'] = $effectiveFilter
        }
        $effectiveSelect = if ($Select) { @($Select) } elseif ($definition.DefaultSelect) { @($definition.DefaultSelect) } else { $null }
        if ($ReportName -eq 'rawRemoteConnectionReports' -and $effectiveSelect) {
            $effectiveSelect = @(
                foreach ($column in $effectiveSelect) {
                    switch ($column) {
                        'SignInDateTime' { 'Timestamp' }
                        'AvailableBandwidthInMbps' { 'AvailableBandwidthInMBps' }
                        default { $column }
                    }
                }
            )
        }
        if ($effectiveSelect) {
            $body['select'] = $effectiveSelect
        }
        if ($PSBoundParameters.ContainsKey('Search')) {
            $body['search'] = $Search
        }
        elseif ($definition.PSObject.Properties.Name -contains 'DefaultSearch') {
            $body['search'] = $definition.DefaultSearch
        }
        if ($GroupBy) {
            $body['groupBy'] = @($GroupBy)
        }
        if ($OrderBy) {
            $body['orderBy'] = @($OrderBy)
        }
        elseif ($definition.PSObject.Properties.Name -contains 'DefaultOrderBy') {
            $body['orderBy'] = @($definition.DefaultOrderBy)
        }
        if ($PSBoundParameters.ContainsKey('Skip')) {
            $body['skip'] = $Skip
        }
        elseif ($definition.PSObject.Properties.Name -contains 'DefaultSkip') {
            $body['skip'] = [int]$definition.DefaultSkip
        }
        if ($PSBoundParameters.ContainsKey('Top')) {
            $body['top'] = $Top
        }

        $uri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/reports/$($definition.Action)"
        $removeOutputFile = -not $OutputFilePath
        if ($OutputFilePath) {
            $reportPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputFilePath)
        }
        else {
            $reportPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "windowscloudpc-report-$ReportName-$([guid]::NewGuid().ToString('N')).json")
        }

        try {
            $parentPath = Split-Path -Path $reportPath -Parent
            if ($parentPath -and -not (Test-Path -LiteralPath $parentPath)) {
                New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
            }

            $jsonBody = $body | ConvertTo-Json -Depth 8
            Invoke-CloudPCGraphRequestWithRetry `
                -Method POST `
                -Uri $uri `
                -Body $jsonBody `
                -ContentType 'application/json' `
                -Headers @{ Prefer = 'include-unknown-enum-members' } `
                -OutputFilePath $reportPath `
                -MaxRetryCount $MaxRetryCount `
                -InitialRetryDelaySeconds $InitialRetryDelaySeconds `
                -MaxRetryDelaySeconds $MaxRetryDelaySeconds `
                -ErrorAction Stop |
                Out-Null

            if (-not (Test-Path -LiteralPath $reportPath)) {
                throw "Graph did not write the expected report file: $reportPath"
            }

            $content = Get-Content -LiteralPath $reportPath -Raw -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($content)) {
                throw "Graph returned an empty report file: $reportPath"
            }

            $payload = $content | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            if ($Raw) {
                [pscustomobject]@{
                    PSTypeName     = 'WindowsCloudPC.ReportPayload'
                    ReportName     = $ReportName
                    Action         = $definition.Action
                    TotalRowCount  = $payload.TotalRowCount
                    Schema         = $payload.Schema
                    Values         = $payload.Values
                    OutputFilePath = $reportPath
                    Raw            = $payload
                }
            }
            else {
                $payload | ConvertFrom-CloudPCReportPayload -ReportName $ReportName -Action $definition.Action -OutputFilePath $reportPath
            }
        }
        finally {
            if ($removeOutputFile -and (Test-Path -LiteralPath $reportPath)) {
                Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    end { }
}
