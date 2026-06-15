$script:CloudPCGroupCache = @{}

function Resolve-CloudPCGroup {
    <#
    .SYNOPSIS
        Resolves an AAD group id to { Id, DisplayName }. Cached per session.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$GroupId
    )

    if ([string]::IsNullOrWhiteSpace($GroupId)) { return $null }
    if ($script:CloudPCGroupCache.ContainsKey($GroupId)) { return $script:CloudPCGroupCache[$GroupId] }

    try {
        $g = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$GroupId`?`$select=id,displayName"
        $info = [pscustomobject]@{ Id = $g.id; DisplayName = $g.displayName }
    }
    catch {
        Write-Verbose "Resolve-CloudPCGroup: could not resolve '$GroupId' ($($_.Exception.Message))"
        $info = [pscustomobject]@{ Id = $GroupId; DisplayName = $null }
    }

    $script:CloudPCGroupCache[$GroupId] = $info
    return $info
}

function Clear-CloudPCGroupCache {
    [CmdletBinding()]
    param()
    $script:CloudPCGroupCache.Clear()
}
