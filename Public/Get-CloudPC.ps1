function Get-CloudPC {
    <#
    .SYNOPSIS
        Returns Windows 365 Cloud PCs in the tenant.

    .DESCRIPTION
        Thin, fast wrapper over /beta/deviceManagement/virtualEndpoint/cloudPCs that returns
        normalized PSCustomObjects (PSTypeName = 'WindowsCloudPC.CloudPC') suitable for piping
        into Get-CloudPCUsage, Where-Object, Format-Table, etc. The raw Graph object is preserved
        on the .Raw property.

    .PARAMETER ProvisioningPolicyId
        Filter to a single provisioning policy.

    .PARAMETER UserPrincipalName
        Filter to Cloud PCs assigned to a specific user (dedicated only — Graph cannot filter
        sharedDeviceDetail by user).

    .PARAMETER Type
        Shared, Dedicated, or All (default).

    .EXAMPLE
        Get-CloudPC | Format-Table Name,ProvisioningType,AssignedUserUpn,ConnectivityStatus

    .EXAMPLE
        Get-CloudPC -ProvisioningPolicyId 8e8a545f-6168-4472-9466-9f05520a5eb3 -Type Shared
    #>
    [CmdletBinding()]
    [OutputType('WindowsCloudPC.CloudPC')]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$ProvisioningPolicyId,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$UserPrincipalName,

        [ValidateSet('Shared','Dedicated','All')]
        [string]$Type = 'All'
    )

    begin {
        Connect-CloudPC | Out-Null
    }

    process {
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

        Invoke-GraphPaged -Uri $uri | ForEach-Object {
            $raw      = $_
            $isShared = ($raw.provisioningType -eq 'sharedByEntraGroup')

            if ($Type -eq 'Shared'    -and -not $isShared) { return }
            if ($Type -eq 'Dedicated' -and      $isShared) { return }

            [pscustomobject]@{
                PSTypeName             = 'WindowsCloudPC.CloudPC'
                Id                     = $raw.id
                Name                   = if ($raw.managedDeviceName) { $raw.managedDeviceName } else { $raw.displayName }
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
    }

    end { }
}
