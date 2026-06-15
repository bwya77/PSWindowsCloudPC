function Invoke-GraphPaged {
    <#
    .SYNOPSIS
        Yields every page of a Microsoft Graph collection request.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Uri,
        [hashtable]$Headers = @{ ConsistencyLevel = 'eventual' }
    )

    begin { }

    process {
        $next = $Uri
        while ($next) {
            $resp = Invoke-MgGraphRequest -Method GET -Uri $next -Headers $Headers
            if ($resp.value) { $resp.value | Write-Output }
            $next = $resp.'@odata.nextLink'
        }
    }

    end { }
}
