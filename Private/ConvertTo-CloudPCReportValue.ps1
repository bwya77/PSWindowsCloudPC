function ConvertTo-CloudPCReportValue {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value,

        [AllowNull()]
        [string]$PropertyType,

        [Parameter(Mandatory)]
        [string]$Column
    )

    begin { }

    process {
        if ($null -eq $Value -or $Value -isnot [string] -or [string]::IsNullOrWhiteSpace($Value)) {
            $Value
        }
        elseif ($PropertyType -eq 'DateTime') {
            try { ([datetime]$Value).ToLocalTime() }
            catch {
                Write-Verbose "ConvertTo-CloudPCReportValue: could not parse DateTime value '$Value' for '$Column'."
                $Value
            }
        }
        elseif ($PropertyType -in @('Int32','Integer')) {
            $parsed = 0
            if ([int]::TryParse($Value, [ref]$parsed)) { $parsed } else { $Value }
        }
        elseif ($PropertyType -eq 'Int64') {
            $parsed = 0L
            if ([long]::TryParse($Value, [ref]$parsed)) { $parsed } else { $Value }
        }
        elseif ($PropertyType -in @('Double','Decimal')) {
            $parsed = 0.0
            if ([double]::TryParse($Value, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) {
                $parsed
            }
            else {
                $Value
            }
        }
        elseif ($PropertyType -eq 'Boolean') {
            $parsed = $false
            if ([bool]::TryParse($Value, [ref]$parsed)) { $parsed } else { $Value }
        }
        else {
            $Value
        }
    }

    end { }
}
