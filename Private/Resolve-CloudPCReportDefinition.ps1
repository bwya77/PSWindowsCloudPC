function Resolve-CloudPCReportDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ReportName
    )

    begin { }

    process {
        $definition = switch ($ReportName) {
            'remoteConnectionHistoricalReports' { @{ Action = 'getRemoteConnectionHistoricalReports'; IncludeReportName = $false; GraphReportName = $ReportName } }
            'dailyAggregatedRemoteConnectionReports' { @{ Action = 'getDailyAggregatedRemoteConnectionReports'; IncludeReportName = $false; GraphReportName = $ReportName } }
            'totalAggregatedRemoteConnectionReports' { @{ Action = 'getTotalAggregatedRemoteConnectionReports'; IncludeReportName = $false; GraphReportName = $ReportName } }
            'noLicenseAvailableConnectivityFailureReport' { @{ Action = 'getFrontlineReport'; IncludeReportName = $true; GraphReportName = $ReportName } }
            'frontlineLicenseUsageReport' { @{ Action = 'getFrontlineReport'; IncludeReportName = $true; GraphReportName = $ReportName } }
            'frontlineLicenseUsageRealTimeReport' { @{ Action = 'getFrontlineReport'; IncludeReportName = $true; GraphReportName = $ReportName } }
            'frontlineLicenseHourlyUsageReport' { @{ Action = 'getFrontlineReport'; IncludeReportName = $true; GraphReportName = $ReportName } }
            'frontlineRealtimeUserConnectionsReport' { @{ Action = 'getFrontlineReport'; IncludeReportName = $true; GraphReportName = $ReportName } }
            'inaccessibleCloudPcReports' { @{ Action = 'getInaccessibleCloudPcReports'; IncludeReportName = $true; GraphReportName = $ReportName } }
            'actionStatusReport' { @{ Action = 'getActionStatusReports'; IncludeReportName = $false; GraphReportName = $ReportName } }
            'rawRemoteConnectionReports' { @{ Action = 'getRawRemoteConnectionReports'; IncludeReportName = $false; GraphReportName = $ReportName } }
            'performanceTrendReport' { @{ Action = 'retrieveCloudPcTenantMetricsReport'; IncludeReportName = $true; GraphReportName = $ReportName } }
            'inaccessibleCloudPcTrendReport' { @{ Action = 'getInaccessibleCloudPcReports'; IncludeReportName = $true; GraphReportName = $ReportName } }
            'regionalConnectionQualityTrendReport' { @{ Action = 'retrieveConnectionQualityReports'; IncludeReportName = $true; GraphReportName = $ReportName } }
            'regionalConnectionQualityInsightsReport' { @{ Action = 'retrieveConnectionQualityReports'; IncludeReportName = $true; GraphReportName = $ReportName } }
            'bulkActionStatusReport' { @{ Action = 'retrieveBulkActionStatusReport'; IncludeReportName = $false; GraphReportName = $ReportName } }
            'cloudPcInsightReport' { @{ Action = 'retrieveCloudPcTenantMetricsReport'; IncludeReportName = $true; GraphReportName = $ReportName } }
            'regionalInaccessibleCloudPcTrendReport' { @{ Action = 'getInaccessibleCloudPcReports'; IncludeReportName = $true; GraphReportName = $ReportName } }
            'cloudPcUsageCategoryReport' { @{ Action = 'retrieveCloudPcRecommendationReports'; IncludeReportName = $true; GraphReportName = $ReportName } }
            'realTimeRemoteConnectionStatus' { @{ Action = 'getRealTimeRemoteConnectionStatus'; IncludeReportName = $false; GraphReportName = $ReportName; Method = 'GET'; SupportsAllCloudPcs = $true } }
        }

        if (-not $definition) {
            throw "Unsupported Cloud PC report name '$ReportName'."
        }

        [pscustomobject]$definition
    }

    end { }
}
