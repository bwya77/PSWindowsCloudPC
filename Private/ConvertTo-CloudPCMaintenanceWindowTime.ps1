function ConvertTo-CloudPCMaintenanceWindowTime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Value,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    begin { }

    process {
        $match = [regex]::Match($Value, '^(?<hour>\d{2}):(?<minute>\d{2})(?::(?<second>\d{2})(?:\.(?<fraction>\d{1,7}))?)?$')
        if (-not $match.Success) {
            Write-Error "New-CloudPCMaintenanceWindow: $PropertyName must be HH:mm or a Graph time-of-day value."
            return
        }

        $hour = [int]$match.Groups['hour'].Value
        $minute = [int]$match.Groups['minute'].Value
        $second = if ($match.Groups['second'].Success) { [int]$match.Groups['second'].Value } else { 0 }
        $fraction = if ($match.Groups['fraction'].Success) {
            $match.Groups['fraction'].Value.PadRight(7, '0')
        }
        else {
            '0000000'
        }

        if ($hour -gt 23 -or $minute -gt 59 -or $second -gt 59) {
            Write-Error "New-CloudPCMaintenanceWindow: $PropertyName must be within a single day."
            return
        }

        $parsed = [timespan]::new(0, $hour, $minute, $second, 0).Add([timespan]::FromTicks([int64]$fraction))
        if ($parsed.TotalMinutes -lt 0 -or $parsed.TotalMinutes -ge 1440) {
            Write-Error "New-CloudPCMaintenanceWindow: $PropertyName must be within a single day."
            return
        }

        $parsed
    }

    end { }
}
