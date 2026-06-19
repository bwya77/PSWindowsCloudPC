function Get-CloudPC {
    <#
    .SYNOPSIS
        Returns Windows 365 Cloud PCs in the tenant.

    .DESCRIPTION
        Thin, fast wrapper over /beta/deviceManagement/virtualEndpoint/cloudPCs that returns
        normalized PSCustomObjects (PSTypeName = 'WindowsCloudPC.CloudPC') suitable for piping
        into Get-CloudPCUsage, Where-Object, Format-Table, etc. The raw Graph object is preserved
        on the .Raw property.

        Name is the Cloud PC displayName, which is the value changed by Rename-CloudPC.
        ManagedDeviceName is returned separately because it can remain unchanged after a
        Cloud PC display name rename.

        The request selects connectivityResult and sends
        Prefer: include-unknown-enum-members so Graph returns evolvable enum
        values such as inUse and underServiceMaintenance.

    .PARAMETER ProvisioningPolicyId
        Filter to a single provisioning policy.

    .PARAMETER UserPrincipalName
        Filter to Cloud PCs assigned to a specific user (dedicated only — Graph cannot filter
        sharedDeviceDetail by user).

    .PARAMETER Id
        Return a single Cloud PC by Cloud PC ID.

    .PARAMETER Name
        Filter by Cloud PC display name or managed device name. Exact matches are used
        unless the value contains wildcard characters. Aliases: DisplayName, ManagedDeviceName.

    .PARAMETER Type
        Shared, Dedicated, or All (default).

    .EXAMPLE
        Get-CloudPC | Format-Table Name,ProvisioningType,AssignedUserUpn,ConnectivityStatus

    .EXAMPLE
        Get-CloudPC -ProvisioningPolicyId 8e8a545f-6168-4472-9466-9f05520a5eb3 -Type Shared

    .EXAMPLE
        Get-CloudPC -Id '95194d88-cec5-4b65-af62-26dbd1814364'

    .EXAMPLE
        Get-CloudPC -Name 'CFD-brad-*'
    #>
    [CmdletBinding()]
    [OutputType('WindowsCloudPC.CloudPC')]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$ProvisioningPolicyId,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$UserPrincipalName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('CloudPcId')]
        [string]$Id,

        [Alias('DisplayName','ManagedDeviceName')]
        [SupportsWildcards()]
        [string]$Name,

        [ValidateSet('Shared','Dedicated','All')]
        [string]$Type = 'All'
    )

    begin {
        Connect-CloudPC | Out-Null
    }

    process {
        if ($Id -and $Name) {
            throw "Get-CloudPC: use either -Id or -Name, not both."
        }

        $filters = @("servicePlanType eq 'enterprise'")
        if ($ProvisioningPolicyId) { $filters += "provisioningPolicyId eq '$ProvisioningPolicyId'" }
        if ($UserPrincipalName)    { $filters += "userPrincipalName eq '$UserPrincipalName'" }
        $filter = ($filters -join ' and ')

        $select = @(
            'id','managedDeviceId','managedDeviceName','displayName','userPrincipalName',
            'status','provisioningType','provisioningPolicyId','provisioningPolicyName',
            'servicePlanName','sharedDeviceDetail','connectivityResult','lastModifiedDateTime',
            'aadDeviceId'
        ) -join ','

        $uri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs' +
               '?$filter=' + [uri]::EscapeDataString($filter) +
               '&$select=' + [uri]::EscapeDataString($select) +
               '&$top=50' +
               '&$orderBy=lastModifiedDateTime%20desc'

        $headers = @{
            ConsistencyLevel = 'eventual'
            Prefer           = 'include-unknown-enum-members'
        }

        $emitCloudPc = {
            param($raw)

            $isShared = ($raw.provisioningType -eq 'sharedByEntraGroup')

            if ($Type -eq 'Shared' -and -not $isShared) { return }
            if ($Type -eq 'Dedicated' -and $isShared) { return }

            $displayName = $raw.displayName
            $managedDeviceName = $raw.managedDeviceName
            $normalizedName = if ($displayName) { $displayName } else { $managedDeviceName }

            if ($Name) {
                $matchValues = @($normalizedName, $displayName, $managedDeviceName) |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                    Select-Object -Unique

                $hasWildcard = [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Name)
                $isNameMatch = if ($hasWildcard) {
                    @($matchValues | Where-Object { $_ -like $Name }).Count -gt 0
                }
                else {
                    @($matchValues | Where-Object { $_ -eq $Name }).Count -gt 0
                }

                if (-not $isNameMatch) { return }
            }

            [pscustomobject]@{
                PSTypeName             = 'WindowsCloudPC.CloudPC'
                Id                     = $raw.id
                Name                   = $normalizedName
                DisplayName            = $displayName
                ManagedDeviceName      = $managedDeviceName
                ProvisioningType       = if ($isShared) { 'Shared' } else { 'Dedicated' }
                ProvisioningPolicyName = $raw.provisioningPolicyName
                ProvisioningPolicyId   = $raw.provisioningPolicyId
                ProvisioningStatus     = $raw.status
                ServicePlanName        = $raw.servicePlanName
                AssignedUserUpn        = if ($isShared) { $raw.sharedDeviceDetail.assignedToUserPrincipalName } else { $raw.userPrincipalName }
                ManagedDeviceId        = $raw.managedDeviceId
                AadDeviceId            = $raw.aadDeviceId
                LastModifiedDateTime   = if ($raw.lastModifiedDateTime) { ([datetime]$raw.lastModifiedDateTime).ToLocalTime() } else { $null }
                Raw                    = $raw
            }
        }

        if ($Id) {
            if ([string]::IsNullOrWhiteSpace($Id)) {
                throw "Get-CloudPC: Id cannot be empty."
            }

            $escapedId = [uri]::EscapeDataString($Id)
            $idUri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/' +
                     $escapedId +
                     '?$select=' + [uri]::EscapeDataString($select)

            $raw = Invoke-MgGraphRequest -Method GET -Uri $idUri -Headers $headers
            & $emitCloudPc $raw
            return
        }

        Invoke-GraphPaged -Uri $uri -Headers $headers | ForEach-Object {
            & $emitCloudPc $_
        }
    }

    end { }
}
