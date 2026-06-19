#Requires -Version 7.0
<#
.SYNOPSIS
    Local-only test functions for Windows 365 Graph report endpoints.

.DESCRIPTION
    Dot-source this file when you want to test the beta Cloud PC report
    endpoints directly with Microsoft.Graph.Authentication. These functions are
    not exported by the WindowsCloudPC module and do not depend on module code.

.EXAMPLE
    . .\scripts\Test-CloudPCReportEndpoints.ps1

    Get-TestCloudPCRealTimeRemoteConnectionStatus -CloudPcId '0cb4034e-bca3-47d6-b945-d9ae9511cf7d' |
        Format-List

.EXAMPLE
    . .\scripts\Test-CloudPCReportEndpoints.ps1

    Get-TestCloudPCFrontlineLicenseUsageReport |
        Sort-Object Timestamp |
        Format-Table Timestamp, DisplayName, LicenseCount, ClaimedLicenseCount, SkuLicenseCount

.EXAMPLE
    . .\scripts\Test-CloudPCReportEndpoints.ps1

    Get-TestCloudPCFrontlineLicenseUsageReport -ReportName frontlineRealtimeUserConnectionsReport |
        Format-Table ConnectedDeviceName, State, CloudPCId, UPN, Timestamp

.EXAMPLE
    . .\scripts\Test-CloudPCReportEndpoints.ps1

    Get-TestCloudPCCurrentUse -CloudPcId '198294a2-4d1d-4c28-bb81-74c3f495a9b2' |
        Format-List

.EXAMPLE
    . .\scripts\Test-CloudPCReportEndpoints.ps1

    Test-TestCloudPCReportLatency -CloudPcId '198294a2-4d1d-4c28-bb81-74c3f495a9b2' -Iterations 5 |
        Sort-Object AverageElapsedMs |
        Format-Table ReportName, Iterations, SuccessCount, AverageElapsedMs, MinElapsedMs, MaxElapsedMs, LastTotalRowCount
#>

function Get-TestCloudPCRealTimeRemoteConnectionStatus {
    <#
    .SYNOPSIS
        Tests getRealTimeRemoteConnectionStatus for one Cloud PC ID.

    .PARAMETER CloudPcId
        The Cloud PC ID to query.

    .PARAMETER SkipConnect
        Use the existing Microsoft Graph connection without calling Connect-MgGraph.

    .PARAMETER Raw
        Return the raw Schema/Values payload instead of normalized rows.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$CloudPcId,

        [switch]$SkipConnect,

        [switch]$Raw
    )

    begin {
        if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
            throw "Microsoft.Graph.Authentication is required. Install it with: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser"
        }

        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

        if (-not $SkipConnect) {
            $scopes = @(
                'CloudPC.Read.All'
                'DeviceManagementConfiguration.Read.All'
                'DeviceManagementManagedDevices.Read.All'
            )
            Connect-MgGraph -Scopes $scopes -NoWelcome | Out-Null
        }
    }

    process {
        $escapedCloudPcId = [uri]::EscapeDataString($CloudPcId)
        $uri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/reports/getRealTimeRemoteConnectionStatus(cloudPcId='$escapedCloudPcId')"
        $tmp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "wcpc-real-time-status-$([guid]::NewGuid().ToString('N')).json")

        try {
            Invoke-MgGraphRequest -Method GET -Uri $uri -OutputFilePath $tmp -ErrorAction Stop | Out-Null

            if (-not (Test-Path -LiteralPath $tmp)) {
                throw "Graph did not write the expected report file: $tmp"
            }

            $json = Get-Content -LiteralPath $tmp -Raw -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($json)) {
                throw "Graph returned an empty report file: $tmp"
            }

            $payload = $json | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            if ($Raw) {
                $payload
                return
            }

            if (-not $payload.Schema) {
                throw "Graph report payload did not include a Schema array."
            }

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

            foreach ($row in $payload.Values) {
                $bag = [ordered]@{}
                for ($i = 0; $i -lt $payload.Schema.Count; $i++) {
                    $column = $payload.Schema[$i].Column
                    $propertyType = $payload.Schema[$i].PropertyType
                    $value = $row[$i]

                    if ($null -ne $value -and $propertyType -eq 'DateTime') {
                        $value = ([datetime]$value).ToLocalTime()
                    }

                    $bag[$column] = $value
                }
                $bag['Raw'] = $payload
                [pscustomobject]$bag
            }
        }
        finally {
            if (Test-Path -LiteralPath $tmp) {
                Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            }
        }
    }

    end { }
}

function Get-TestCloudPCFrontlineLicenseUsageReport {
    <#
    .SYNOPSIS
        Tests microsoft.graph.getFrontlineReport for Windows 365 Frontline reports.

    .PARAMETER ReportName
        The frontline report name to request. Defaults to frontlineLicenseUsageReport.

        Known frontline values:
        - frontlineLicenseUsageReport
        - frontlineLicenseUsageRealTimeReport
        - frontlineLicenseHourlyUsageReport
        - frontlineRealtimeUserConnectionsReport

    .PARAMETER SkipConnect
        Use the existing Microsoft Graph connection without calling Connect-MgGraph.

    .PARAMETER Raw
        Return the raw Schema/Values payload instead of normalized rows.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet(
            'frontlineLicenseUsageReport',
            'frontlineLicenseUsageRealTimeReport',
            'frontlineLicenseHourlyUsageReport',
            'frontlineRealtimeUserConnectionsReport'
        )]
        [string]$ReportName = 'frontlineLicenseUsageReport',

        [switch]$SkipConnect,

        [switch]$Raw
    )

    begin {
        if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
            throw "Microsoft.Graph.Authentication is required. Install it with: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser"
        }

        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

        if (-not $SkipConnect) {
            $scopes = @(
                'CloudPC.Read.All'
                'DeviceManagementConfiguration.Read.All'
                'DeviceManagementManagedDevices.Read.All'
            )
            Connect-MgGraph -Scopes $scopes -NoWelcome | Out-Null
        }
    }

    process {
        $uri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/reports/microsoft.graph.getFrontlineReport'
        $body = @{ reportName = $ReportName } | ConvertTo-Json -Depth 3
        $tmp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "wcpc-frontline-report-$([guid]::NewGuid().ToString('N')).json")

        try {
            Invoke-MgGraphRequest -Method POST -Uri $uri -Body $body -ContentType 'application/json' -OutputFilePath $tmp -ErrorAction Stop | Out-Null

            if (-not (Test-Path -LiteralPath $tmp)) {
                throw "Graph did not write the expected report file: $tmp"
            }

            $json = Get-Content -LiteralPath $tmp -Raw -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($json)) {
                throw "Graph returned an empty report file: $tmp"
            }

            $payload = $json | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            if ($Raw) {
                $payload
                return
            }

            if (-not $payload.Schema) {
                throw "Graph report payload did not include a Schema array."
            }

            foreach ($row in $payload.Values) {
                $bag = [ordered]@{}
                for ($i = 0; $i -lt $payload.Schema.Count; $i++) {
                    $column = $payload.Schema[$i].Column
                    $propertyType = $payload.Schema[$i].PropertyType
                    $value = $row[$i]

                    if ($null -ne $value -and $propertyType -eq 'DateTime') {
                        $value = ([datetime]$value).ToLocalTime()
                    }

                    $bag[$column] = $value
                }
                $bag['Raw'] = $payload
                [pscustomobject]$bag
            }
        }
        finally {
            if (Test-Path -LiteralPath $tmp) {
                Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            }
        }
    }

    end { }
}

function ConvertFrom-TestCloudPCReportPayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [hashtable]$Payload
    )

    begin { }

    process {
        if (-not $Payload.Schema -or -not $Payload.Values) {
            return
        }

        foreach ($row in $Payload.Values) {
            $bag = [ordered]@{}
            for ($i = 0; $i -lt $Payload.Schema.Count; $i++) {
                $column = $Payload.Schema[$i].Column
                $propertyType = $Payload.Schema[$i].PropertyType
                $value = $row[$i]

                if ($null -ne $value -and $propertyType -eq 'DateTime') {
                    $value = ([datetime]$value).ToLocalTime()
                }

                $bag[$column] = $value
            }

            [pscustomobject]$bag
        }
    }

    end { }
}

function Get-TestCloudPCCurrentUse {
    <#
    .SYNOPSIS
        Tests whether one Cloud PC appears to be in use and returns available user/device clues.

    .DESCRIPTION
        Combines two beta report endpoints:

        - getRealTimeRemoteConnectionStatus(cloudPcId='...') for SignInStatus,
          DaysSinceLastSignIn, and LastActiveTime.
        - getFrontlineReport with frontlineRealtimeUserConnectionsReport for
          FrontlineState, UPN, ConnectedDeviceName, and IntuneDeviceId.

        The IsInUse value is based on SignInStatus from the per-Cloud PC real-time
        connection endpoint. The frontline report is included as supporting
        evidence because it can identify the matching CloudPCId, state, UPN, and
        device identifiers when Graph has those values.

    .PARAMETER CloudPcId
        The Cloud PC ID to query.

    .PARAMETER SkipConnect
        Use the existing Microsoft Graph connection without calling Connect-MgGraph.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$CloudPcId,

        [switch]$SkipConnect
    )

    begin {
        if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
            throw "Microsoft.Graph.Authentication is required. Install it with: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser"
        }

        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

        if (-not $SkipConnect) {
            $scopes = @(
                'CloudPC.Read.All'
                'DeviceManagementConfiguration.Read.All'
                'DeviceManagementManagedDevices.Read.All'
            )
            Connect-MgGraph -Scopes $scopes -NoWelcome | Out-Null
        }
    }

    process {
        $realTimeStatus = Get-TestCloudPCRealTimeRemoteConnectionStatus -CloudPcId $CloudPcId -SkipConnect
        $frontlineConnection = Get-TestCloudPCFrontlineLicenseUsageReport -ReportName frontlineRealtimeUserConnectionsReport -SkipConnect |
            Where-Object { $_.CloudPCId -eq $CloudPcId } |
            Sort-Object Timestamp -Descending |
            Select-Object -First 1

        $currentUserUpn = if (-not [string]::IsNullOrWhiteSpace($frontlineConnection.UPN)) {
            $frontlineConnection.UPN
        }
        else {
            $null
        }

        [pscustomobject]@{
            CloudPcId                 = $CloudPcId
            ManagedDeviceName         = $realTimeStatus.ManagedDeviceName
            IsInUse                   = $realTimeStatus.SignInStatus -eq 'SignedIn'
            SignInStatus              = $realTimeStatus.SignInStatus
            DaysSinceLastSignIn       = $realTimeStatus.DaysSinceLastSignIn
            LastActiveTime            = $realTimeStatus.LastActiveTime
            FrontlineState            = $frontlineConnection.State
            CurrentUserUpn            = $currentUserUpn
            ConnectedDeviceName       = $frontlineConnection.ConnectedDeviceName
            IntuneDeviceId            = $frontlineConnection.IntuneDeviceId
            ConcurrentAccessGroupId   = $frontlineConnection.ConcurrentAccessGroupId
            ServicePlanId             = $frontlineConnection.ServicePlanId
            FrontlineTimestamp        = $frontlineConnection.Timestamp
            FrontlineCreatedDateTime  = $frontlineConnection.CreatedDateTimeUTC
            RawRealTimeStatus         = $realTimeStatus.Raw
            RawFrontlineConnection    = $frontlineConnection.Raw
        }
    }

    end { }
}

function Test-TestCloudPCReportLatency {
    <#
    .SYNOPSIS
        Times local calls to Cloud PC report endpoints.

    .DESCRIPTION
        Runs the selected Frontline getFrontlineReport names and, when CloudPcId
        is provided, also runs getRealTimeRemoteConnectionStatus for that Cloud
        PC. Authentication is done once unless -SkipConnect is used, then each
        measured call reuses the existing Graph session.

        The output is grouped by report with min, max, and average elapsed
        milliseconds. It also surfaces status-like fields when a report returns
        them, such as SignInStatus, State, UPN, and ConnectedDeviceName. Use
        -Detailed to return one row per attempt instead.

    .PARAMETER CloudPcId
        Optional Cloud PC ID used to test getRealTimeRemoteConnectionStatus.

    .PARAMETER ReportName
        The Frontline getFrontlineReport names to test. Defaults to all known
        Frontline report names in this script.

    .PARAMETER Iterations
        Number of times to call each report.

    .PARAMETER Detailed
        Return one row per attempt instead of aggregated timings.

    .PARAMETER SkipConnect
        Use the existing Microsoft Graph connection without calling Connect-MgGraph.
    #>
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$CloudPcId,

        [ValidateSet(
            'frontlineLicenseUsageReport',
            'frontlineLicenseUsageRealTimeReport',
            'frontlineLicenseHourlyUsageReport',
            'frontlineRealtimeUserConnectionsReport'
        )]
        [string[]]$ReportName = @(
            'frontlineLicenseUsageReport',
            'frontlineLicenseUsageRealTimeReport',
            'frontlineLicenseHourlyUsageReport',
            'frontlineRealtimeUserConnectionsReport'
        ),

        [ValidateRange(1, 50)]
        [int]$Iterations = 3,

        [switch]$Detailed,

        [switch]$SkipConnect
    )

    begin {
        if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
            throw "Microsoft.Graph.Authentication is required. Install it with: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser"
        }

        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

        if (-not $SkipConnect) {
            $scopes = @(
                'CloudPC.Read.All'
                'DeviceManagementConfiguration.Read.All'
                'DeviceManagementManagedDevices.Read.All'
            )
            Connect-MgGraph -Scopes $scopes -NoWelcome | Out-Null
        }
    }

    process {
        $measurements = New-Object System.Collections.Generic.List[object]

        for ($iteration = 1; $iteration -le $Iterations; $iteration++) {
            if ($CloudPcId) {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                $payload = $null
                $errorMessage = $null

                try {
                    $payload = Get-TestCloudPCRealTimeRemoteConnectionStatus -CloudPcId $CloudPcId -SkipConnect -Raw
                }
                catch {
                    $errorMessage = $_.Exception.Message
                }
                finally {
                    $stopwatch.Stop()
                }

                $statusRow = $null
                if ($payload) {
                    $statusRow = $payload | ConvertFrom-TestCloudPCReportPayload | Select-Object -First 1
                }

                $measurements.Add([pscustomobject]@{
                    ReportName          = 'getRealTimeRemoteConnectionStatus'
                    Endpoint            = 'reports/getRealTimeRemoteConnectionStatus'
                    Iteration           = $iteration
                    ElapsedMs           = [math]::Round($stopwatch.Elapsed.TotalMilliseconds, 2)
                    Success             = -not $errorMessage
                    TotalRowCount       = $payload.TotalRowCount
                    ValueRowCount       = @($payload.Values).Count
                    SignInStatus        = $statusRow.SignInStatus
                    State               = $null
                    CurrentUserUpn      = $null
                    ConnectedDeviceName = $statusRow.ManagedDeviceName
                    Error               = $errorMessage
                })
            }

            foreach ($name in $ReportName) {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                $payload = $null
                $errorMessage = $null

                try {
                    $payload = Get-TestCloudPCFrontlineLicenseUsageReport -ReportName $name -SkipConnect -Raw
                }
                catch {
                    $errorMessage = $_.Exception.Message
                }
                finally {
                    $stopwatch.Stop()
                }

                $rows = @()
                if ($payload) {
                    $rows = @($payload | ConvertFrom-TestCloudPCReportPayload)
                }

                $statusRow = if ($CloudPcId) {
                    $rows |
                        Where-Object { $_.CloudPCId -eq $CloudPcId -or $_.CloudPcId -eq $CloudPcId } |
                        Sort-Object Timestamp, DateTimeUTC -Descending |
                        Select-Object -First 1
                }
                else {
                    $rows | Select-Object -First 1
                }

                $measurements.Add([pscustomobject]@{
                    ReportName          = $name
                    Endpoint            = 'reports/microsoft.graph.getFrontlineReport'
                    Iteration           = $iteration
                    ElapsedMs           = [math]::Round($stopwatch.Elapsed.TotalMilliseconds, 2)
                    Success             = -not $errorMessage
                    TotalRowCount       = $payload.TotalRowCount
                    ValueRowCount       = @($payload.Values).Count
                    SignInStatus        = $null
                    State               = $statusRow.State
                    CurrentUserUpn      = $statusRow.UPN
                    ConnectedDeviceName = if ($statusRow.ConnectedDeviceName) { $statusRow.ConnectedDeviceName } else { $statusRow.DeviceName }
                    Error               = $errorMessage
                })
            }
        }

        if ($Detailed) {
            $measurements
            return
        }

        $measurements |
            Group-Object ReportName |
            ForEach-Object {
                $group = $_.Group
                $successful = @($group | Where-Object Success)
                $last = $group | Select-Object -Last 1

                [pscustomobject]@{
                    ReportName        = $_.Name
                    Endpoint          = $last.Endpoint
                    Iterations        = $group.Count
                    SuccessCount      = $successful.Count
                    FailureCount      = $group.Count - $successful.Count
                    AverageElapsedMs  = if ($successful) { [math]::Round(($successful | Measure-Object ElapsedMs -Average).Average, 2) } else { $null }
                    MinElapsedMs      = if ($successful) { [math]::Round(($successful | Measure-Object ElapsedMs -Minimum).Minimum, 2) } else { $null }
                    MaxElapsedMs      = if ($successful) { [math]::Round(($successful | Measure-Object ElapsedMs -Maximum).Maximum, 2) } else { $null }
                    LastTotalRowCount = $last.TotalRowCount
                    LastValueRowCount = $last.ValueRowCount
                    LastSignInStatus  = $last.SignInStatus
                    LastState         = $last.State
                    LastUserUpn       = $last.CurrentUserUpn
                    LastDeviceName    = $last.ConnectedDeviceName
                    LastError         = ($group | Where-Object { -not $_.Success } | Select-Object -Last 1).Error
                }
            }
    }

    end { }
}
