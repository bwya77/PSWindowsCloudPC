function Connect-CloudPC {
    <#
    .SYNOPSIS
        Connects to Microsoft Graph with the scopes required by WindowsCloudPC.

    .DESCRIPTION
        Idempotent: if an existing Graph session already covers the required scopes, no prompt
        is shown. Use -Force to re-authenticate (e.g. to add scopes or switch accounts).
        Connect-Windows365 is exported as an alias for this command.

    .PARAMETER AdditionalScopes
        Extra Graph scopes to request on top of the module defaults.

    .PARAMETER Force
        Disconnect any existing session and re-authenticate.

    .EXAMPLE
        Connect-CloudPC

    .EXAMPLE
        Connect-CloudPC -AdditionalScopes 'CloudPC.ReadWrite.All'

    .EXAMPLE
        Connect-Windows365
    #>
    [CmdletBinding()]
    param(
        [string[]]$AdditionalScopes,
        [switch]$Force
    )

    begin {
        if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
            throw "Microsoft.Graph.Authentication is required. Install: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser"
        }
        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    }

    process {
        $defaultScopes = @(
            'CloudPC.Read.All',
            'DeviceManagementManagedDevices.Read.All',
            'User.Read.All',
            'Group.Read.All'
        )
        $scopes = @($defaultScopes + $AdditionalScopes | Where-Object { $_ } | Select-Object -Unique)

        if ($Force) {
            try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null }
            catch { Write-Verbose "Disconnect-MgGraph: $($_.Exception.Message)" }
        }

        $ctx = Get-MgContext
        $missing = $scopes | Where-Object { -not $ctx -or $_ -notin $ctx.Scopes }
        if ($missing) {
            Write-Verbose "Connecting to Microsoft Graph with scopes: $($scopes -join ', ')"
            Connect-MgGraph -Scopes $scopes -NoWelcome | Out-Null
            $ctx = Get-MgContext
        }

        $ctx
    }

    end { }
}
