function ConvertFrom-CloudPCReportPayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [hashtable]$Payload,

        [Parameter(Mandatory)]
        [string]$ReportName,

        [Parameter(Mandatory)]
        [string]$Action,

        [string]$OutputFilePath
    )

    begin { }

    process {
        if (-not $Payload.Schema) {
            throw "Graph report payload for '$ReportName' did not include a Schema array."
        }

        $values = @($Payload.Values)
        $rows = New-Object System.Collections.Generic.List[object]
        if ($values.Count -gt 0 -and $values[0] -is [array]) {
            foreach ($valueRow in $values) {
                $rows.Add($valueRow)
            }
        }
        else {
            $rows.Add($values)
        }

        foreach ($row in $rows) {
            $bag = [ordered]@{
                PSTypeName     = 'WindowsCloudPC.ReportRow'
                ReportName     = $ReportName
                Action         = $Action
                TotalRowCount  = $Payload.TotalRowCount
                OutputFilePath = $OutputFilePath
            }
            $seenColumns = @{}

            for ($i = 0; $i -lt $Payload.Schema.Count; $i++) {
                $column = $Payload.Schema[$i].Column
                if ([string]::IsNullOrWhiteSpace($column)) {
                    $column = "Column$i"
                }

                if ($seenColumns.ContainsKey($column)) {
                    $seenColumns[$column]++
                    $column = "$column$($seenColumns[$column])"
                }
                else {
                    $seenColumns[$column] = 0
                }

                $value = if ($i -lt $row.Count) { $row[$i] } else { $null }
                $bag[$column] = ConvertTo-CloudPCReportValue -Value $value -PropertyType $Payload.Schema[$i].PropertyType -Column $column
            }

            $bag['RawValues'] = $row
            $bag['Raw'] = $Payload
            [pscustomobject]$bag
        }
    }

    end { }
}
