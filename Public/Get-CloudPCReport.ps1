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

    .PARAMETER ReportName
        The Microsoft Graph beta cloudPcReportName enum member to retrieve.

    .PARAMETER CloudPcId
        Optional Cloud PC ID used to build the required CloudPcId filter for
        reports that are scoped to one Cloud PC, such as
        remoteConnectionHistoricalReports. If Filter is also provided, the
        CloudPcId clause is combined with it.

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
            'cloudPcUsageCategoryReport'
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
            Invoke-MgGraphRequest `
                -Method POST `
                -Uri $uri `
                -Body $jsonBody `
                -ContentType 'application/json' `
                -Headers @{ Prefer = 'include-unknown-enum-members' } `
                -OutputFilePath $reportPath `
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
