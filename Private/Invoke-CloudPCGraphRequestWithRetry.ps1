function Invoke-CloudPCGraphRequestWithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('GET','POST','PATCH','DELETE')]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Uri,

        [hashtable]$Headers,

        [string]$Body,

        [string]$ContentType,

        [string]$OutputFilePath,

        [ValidateRange(0, 10)]
        [int]$MaxRetryCount = 6,

        [ValidateRange(1, 3600)]
        [int]$InitialRetryDelaySeconds = 3,

        [ValidateRange(1, 3600)]
        [int]$MaxRetryDelaySeconds = 120
    )

    begin { }

    process {
        $attempt = 0
        while ($true) {
            $params = @{
                Method      = $Method
                Uri         = $Uri
                ErrorAction = 'Stop'
            }
            if ($Headers) { $params['Headers'] = $Headers }
            if ($Body) { $params['Body'] = $Body }
            if ($ContentType) { $params['ContentType'] = $ContentType }
            if ($OutputFilePath) { $params['OutputFilePath'] = $OutputFilePath }

            try {
                Invoke-MgGraphRequest @params
                return
            }
            catch {
                $statusCode = Get-CloudPCGraphStatusCode -ErrorRecord $_
                if ($statusCode -notin @(429, 503, 504) -or $attempt -ge $MaxRetryCount) {
                    throw
                }

                $retryAfter = Get-CloudPCGraphRetryAfterDelay -ErrorRecord $_
                if ($null -eq $retryAfter) {
                    $retryAfter = [math]::Min(
                        $MaxRetryDelaySeconds,
                        $InitialRetryDelaySeconds * [math]::Pow(2, $attempt)
                    )
                }

                $retryAfter = [int][math]::Max(1, [math]::Min($MaxRetryDelaySeconds, [math]::Ceiling($retryAfter)))
                Write-Verbose "Graph request was throttled or temporarily unavailable (HTTP $statusCode). Retrying in $retryAfter seconds. Attempt $($attempt + 1) of $MaxRetryCount."
                Start-Sleep -Seconds $retryAfter
                $attempt++
            }
        }
    }

    end { }
}

function Get-CloudPCGraphStatusCode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $response = $ErrorRecord.Exception.Response
    if ($response -and $response.PSObject.Properties.Name -contains 'StatusCode') {
        return [int]$response.StatusCode
    }
    if ($ErrorRecord.Exception.PSObject.Properties.Name -contains 'StatusCode') {
        return [int]$ErrorRecord.Exception.StatusCode
    }
    if ($ErrorRecord.Exception.Message -match '\b(429|503|504)\b') {
        return [int]$Matches[1]
    }
    if ($ErrorRecord.Exception.Message -match 'Too\s+Many\s+Requests') {
        return 429
    }

    $null
}

function Get-CloudPCGraphRetryAfterDelay {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $response = $ErrorRecord.Exception.Response
    $headers = if ($response -and $response.PSObject.Properties.Name -contains 'Headers') { $response.Headers } else { $null }
    if ($headers) {
        $retryAfter = $headers.RetryAfter
        if ($retryAfter) {
            if ($retryAfter.Delta) {
                return $retryAfter.Delta.TotalSeconds
            }
            if ($retryAfter.Date) {
                return ([datetimeoffset]$retryAfter.Date).UtcDateTime.Subtract([datetime]::UtcNow).TotalSeconds
            }
        }

        try {
            $headerValue = $headers['Retry-After']
            if ($headerValue) {
                $seconds = 0
                if ([int]::TryParse([string]$headerValue, [ref]$seconds)) {
                    return $seconds
                }

                $date = [datetimeoffset]::MinValue
                if ([datetimeoffset]::TryParse([string]$headerValue, [ref]$date)) {
                    return $date.UtcDateTime.Subtract([datetime]::UtcNow).TotalSeconds
                }
            }
        }
        catch {
            Write-Verbose "Could not parse Retry-After header: $($_.Exception.Message)"
        }
    }

    if ($ErrorRecord.Exception.Message -match 'Retry-After:\s*(\d+)') {
        return [int]$Matches[1]
    }

    $null
}
