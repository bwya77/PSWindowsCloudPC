function Get-CloudPCManagedDevice {
    <#
    .SYNOPSIS
        Returns the Intune managedDevice record for a given managedDeviceId, including usersLoggedOn.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ManagedDeviceId
    )

    begin { }

    process {
        $select = 'id,deviceName,userPrincipalName,userDisplayName,lastSyncDateTime,usersLoggedOn,azureADDeviceId'
        $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$ManagedDeviceId')?`$select=$select"

        try {
            Invoke-MgGraphRequest -Method GET -Uri $uri
        }
        catch {
            Write-Verbose "Get-CloudPCManagedDevice: $ManagedDeviceId not found ($($_.Exception.Message))"
            $null
        }
    }

    end { }
}
