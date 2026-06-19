BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CloudPCReport' {
    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest {
            $payload = @{
                TotalRowCount = 1
                Schema = @(
                    @{ Column = 'Timestamp'; PropertyType = 'DateTime' }
                    @{ Column = 'CloudPcId'; PropertyType = 'String' }
                    @{ Column = 'RoundTripTimeInMs'; PropertyType = 'Double' }
                )
                Values = @(
                    @('2026-06-17T19:29:32Z', 'cpc-1', '16.5')
                )
            } | ConvertTo-Json -Depth 8

            Set-Content -LiteralPath $OutputFilePath -Value $payload -Encoding utf8NoBOM
        }
    }

    It 'maps frontline report names to getFrontlineReport and parses schema rows' {
        $rows = Get-CloudPCReport -ReportName frontlineLicenseUsageReport -Top 10

        $rows | Should -HaveCount 1
        $rows[0].PSObject.TypeNames | Should -Contain 'WindowsCloudPC.ReportRow'
        $rows[0].ReportName | Should -Be 'frontlineLicenseUsageReport'
        $rows[0].Action | Should -Be 'getFrontlineReport'
        $rows[0].Timestamp | Should -BeOfType [datetime]
        $rows[0].RoundTripTimeInMs | Should -BeOfType [double]
        $rows[0].RoundTripTimeInMs | Should -Be 16.5

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'POST' -and
            $Uri -eq 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/reports/getFrontlineReport' -and
            ($Body | ConvertFrom-Json).reportName -eq 'frontlineLicenseUsageReport' -and
            ($Body | ConvertFrom-Json).top -eq 10
        }
    }

    It 'omits reportName for action status reports' {
        Get-CloudPCReport -ReportName actionStatusReport | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/reports/getActionStatusReports' -and
            -not (($Body | ConvertFrom-Json).PSObject.Properties.Name -contains 'reportName')
        }
    }

    It 'passes select, filter, search, groupBy, orderBy, and skip in the body' {
        Get-CloudPCReport `
            -ReportName regionalConnectionQualityTrendReport `
            -CloudPcId 'cpc-1' `
            -Select CloudPcId,ManagedDeviceName `
            -Filter "ManagedDeviceName eq 'CPC-1'" `
            -Search 'cpc' `
            -GroupBy CloudPcId `
            -OrderBy 'CloudPcId asc' `
            -Skip 5 |
            Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $parsedBody = $Body | ConvertFrom-Json
            $Uri -eq 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/reports/retrieveConnectionQualityReports' -and
            $parsedBody.reportName -eq 'regionalConnectionQualityTrendReport' -and
            $parsedBody.select -contains 'CloudPcId' -and
            $parsedBody.filter -eq "CloudPcId eq 'cpc-1' and (ManagedDeviceName eq 'CPC-1')" -and
            $parsedBody.search -eq 'cpc' -and
            $parsedBody.groupBy -contains 'CloudPcId' -and
            $parsedBody.orderBy -contains 'CloudPcId asc' -and
            $parsedBody.skip -eq 5
        }
    }

    It 'requires a CloudPcId filter for remote connection historical reports' {
        { Get-CloudPCReport -ReportName remoteConnectionHistoricalReports -Top 10 } |
            Should -Throw -ExpectedMessage '*requires -CloudPcId or -Filter with a CloudPcId clause*'
    }

    It 'requires an ActivityId filter for raw remote connection reports' {
        { Get-CloudPCReport -ReportName rawRemoteConnectionReports -Top 10 } |
            Should -Throw -ExpectedMessage '*requires -ActivityId or -Filter with an ActivityId clause*'
    }

    It 'returns a raw payload and preserves the requested output file' {
        $path = Join-Path $TestDrive 'report.json'

        $payload = Get-CloudPCReport -ReportName rawRemoteConnectionReports -ActivityId 'activity-1' -OutputFilePath $path -Raw

        $payload.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.ReportPayload'
        $payload.Action | Should -Be 'getRawRemoteConnectionReports'
        $payload.Schema | Should -HaveCount 3
        Test-Path -LiteralPath $path | Should -BeTrue
    }

    It 'normalizes common raw remote connection select aliases to Graph stream columns' {
        Get-CloudPCReport `
            -ReportName rawRemoteConnectionReports `
            -ActivityId 'activity-1' `
            -Select SignInDateTime,RoundTripTimeInMs,AvailableBandwidthInMbps |
            Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Body -clike '*Timestamp*' -and
            $Body -clike '*RoundTripTimeInMs*' -and
            $Body -clike '*AvailableBandwidthInMBps*' -and
            $Body -cnotlike '*SignInDateTime*' -and
            $Body -cnotlike '*AvailableBandwidthInMbps"*'
        }
    }

    It 'rejects deprecated, unsupported, and live-failing report names at binding time' -ForEach @(
        'remoteConnectionQualityReports',
        'cloudPcUsageCategoryReports',
        'crossRegionDisasterRecoveryReport',
        'remoteConnectionQualityReport',
        'troubleshootDetailsReport',
        'troubleshootTrendCountReport',
        'troubleshootRegionalReport',
        'troubleshootIssueCountReport',
        'cloudPCInventoryReport'
    ) {
        { Get-CloudPCReport -ReportName $_ } | Should -Throw -ExpectedMessage '*ValidateSet*'
    }
}
