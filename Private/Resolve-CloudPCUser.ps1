$script:CloudPCUserCache = @{}

function Resolve-CloudPCUser {
    <#
    .SYNOPSIS
        Resolves an AAD object id OR a UPN to { Id, Upn, DisplayName }. Cached per session.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$IdOrUpn
    )

    begin { }

    process {
        if ([string]::IsNullOrWhiteSpace($IdOrUpn)) {
            return
        }
        if ($script:CloudPCUserCache.ContainsKey($IdOrUpn)) {
            $script:CloudPCUserCache[$IdOrUpn]
            return
        }

        try {
            $escaped = [uri]::EscapeDataString($IdOrUpn)
            $u = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$escaped`?`$select=id,userPrincipalName,displayName"
            $info = [pscustomobject]@{
                Id          = $u.id
                Upn         = $u.userPrincipalName
                DisplayName = $u.displayName
            }
        }
        catch {
            Write-Verbose "Resolve-CloudPCUser: could not resolve '$IdOrUpn' ($($_.Exception.Message))"
            $info = [pscustomobject]@{ Id = $null; Upn = $IdOrUpn; DisplayName = $null }
        }

        $script:CloudPCUserCache[$IdOrUpn] = $info
        $info
    }

    end { }
}

function Clear-CloudPCUserCache {
    [CmdletBinding()]
    param()

    begin { }

    process {
        $script:CloudPCUserCache.Clear()
    }

    end { }
}
