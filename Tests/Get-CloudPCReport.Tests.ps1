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

    It 'calls real-time remote connection status with GET for a single Cloud PC' {
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest -MockWith {
            $payload = @{
                TotalRowCount = 1
                Schema = @(
                    @{ Column = 'ManagedDeviceName'; PropertyType = 'String' }
                    @{ Column = 'CloudPcId'; PropertyType = 'String' }
                    @{ Column = 'DaysSinceLastSignIn'; PropertyType = 'Int64' }
                    @{ Column = 'SignInStatus'; PropertyType = 'String' }
                    @{ Column = 'LastActiveTime'; PropertyType = 'DateTime' }
                )
                Values = @(
                    @('CPC-1', 'cpc-1', 0, 'SignedIn', '2026-06-19T05:20:28')
                )
            } | ConvertTo-Json -Depth 8

            Set-Content -LiteralPath $OutputFilePath -Value $payload -Encoding utf8NoBOM
        }

        $rows = Get-CloudPCReport -ReportName realTimeRemoteConnectionStatus -CloudPcId 'cpc-1'

        $rows | Should -HaveCount 1
        $rows[0].ReportName | Should -Be 'realTimeRemoteConnectionStatus'
        $rows[0].Action | Should -Be 'getRealTimeRemoteConnectionStatus'
        $rows[0].CloudPcId | Should -Be 'cpc-1'
        $rows[0].SignInStatus | Should -Be 'SignedIn'
        $rows[0].DaysSinceLastSignIn | Should -BeOfType [long]
        $rows[0].LastActiveTime | Should -BeOfType [datetime]

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and
            $Uri -eq "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/reports/getRealTimeRemoteConnectionStatus(cloudPcId='cpc-1')" -and
            -not $PSBoundParameters.ContainsKey('Body')
        }
    }

    It 'retries real-time remote connection status when Graph throttles' {
        $script:ThrottleAttemptCount = 0
        Mock -ModuleName WindowsCloudPC Start-Sleep { }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest -MockWith {
            $script:ThrottleAttemptCount++
            if ($script:ThrottleAttemptCount -eq 1) {
                throw 'Response status code does not indicate success: 429 (Too Many Requests). Retry-After: 1'
            }

            $payload = @{
                TotalRowCount = 1
                Schema = @(
                    @{ Column = 'ManagedDeviceName'; PropertyType = 'String' }
                    @{ Column = 'CloudPcId'; PropertyType = 'String' }
                    @{ Column = 'DaysSinceLastSignIn'; PropertyType = 'Int64' }
                    @{ Column = 'SignInStatus'; PropertyType = 'String' }
                    @{ Column = 'LastActiveTime'; PropertyType = 'DateTime' }
                )
                Values = @(
                    @('CPC-1', 'cpc-1', 0, 'SignedIn', '2026-06-19T05:20:28')
                )
            } | ConvertTo-Json -Depth 8

            Set-Content -LiteralPath $OutputFilePath -Value $payload -Encoding utf8NoBOM
        }

        $rows = Get-CloudPCReport -ReportName realTimeRemoteConnectionStatus -CloudPcId 'cpc-1' -MaxRetryCount 1

        $rows | Should -HaveCount 1
        $script:ThrottleAttemptCount | Should -Be 2
        Should -Invoke -ModuleName WindowsCloudPC Start-Sleep -Times 1 -Exactly -ParameterFilter {
            $Seconds -eq 1
        }
    }

    It 'enumerates all Cloud PCs for real-time remote connection status when CloudPcId is omitted' {
        Mock -ModuleName WindowsCloudPC Get-CloudPC -MockWith {
            @(
                [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-1'; Name = 'CPC-1' }
                [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-never-used'; Name = 'CPC-NEVER-USED' }
            )
        }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest -MockWith {
            $cloudPcId = if ($Uri -match "cloudPcId='([^']+)'") { $Matches[1] } else { 'unknown' }
            $payload = if ($cloudPcId -eq 'cpc-never-used') {
                @{
                    TotalRowCount = 0
                    Schema = @(
                        @{ Column = 'ManagedDeviceName'; PropertyType = 'String' }
                        @{ Column = 'CloudPcId'; PropertyType = 'String' }
                        @{ Column = 'DaysSinceLastSignIn'; PropertyType = 'Int64' }
                        @{ Column = 'SignInStatus'; PropertyType = 'String' }
                        @{ Column = 'LastActiveTime'; PropertyType = 'DateTime' }
                    )
                    Values = @()
                }
            }
            else {
                @{
                    TotalRowCount = 1
                    Schema = @(
                        @{ Column = 'ManagedDeviceName'; PropertyType = 'String' }
                        @{ Column = 'CloudPcId'; PropertyType = 'String' }
                        @{ Column = 'DaysSinceLastSignIn'; PropertyType = 'Int64' }
                        @{ Column = 'SignInStatus'; PropertyType = 'String' }
                        @{ Column = 'LastActiveTime'; PropertyType = 'DateTime' }
                    )
                    Values = @(
                        @('CPC-1', 'cpc-1', 0, 'NotSignedIn', '2026-06-19T05:20:28')
                    )
                }
            }

            Set-Content -LiteralPath $OutputFilePath -Value ($payload | ConvertTo-Json -Depth 8) -Encoding utf8NoBOM
        }

        $rows = Get-CloudPCReport -ReportName realTimeRemoteConnectionStatus

        $rows | Should -HaveCount 2
        ($rows | Where-Object CloudPcId -eq 'cpc-never-used').ManagedDeviceName | Should -Be 'CPC-NEVER-USED'
        ($rows | Where-Object CloudPcId -eq 'cpc-never-used').SignInStatus | Should -Be 'NotSignedIn'

        Should -Invoke -ModuleName WindowsCloudPC Get-CloudPC -Times 1 -Exactly
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 2 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and
            $Uri -like "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/reports/getRealTimeRemoteConnectionStatus*"
        }
    }

    It 'rejects body-style report parameters for real-time remote connection status' {
        { Get-CloudPCReport -ReportName realTimeRemoteConnectionStatus -Filter "CloudPcId eq 'cpc-1'" } |
            Should -Throw -ExpectedMessage '*does not support*Filter*'
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
