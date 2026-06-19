function Get-CloudPCServicePlan {
    <#
    .SYNOPSIS
        Returns Windows 365 Cloud PC service plans.

    .DESCRIPTION
        Calls the Microsoft Graph beta
        https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/servicePlans
        endpoint and returns the Cloud PC service plans available to the tenant.

        The Graph servicePlans API does not support OData query parameters, so
        DisplayName and Type filters are applied client-side.

    .PARAMETER DisplayName
        Optional exact display name filter. Alias: Name.

    .PARAMETER Type
        Optional service plan type filter, such as enterprise or business.

    .EXAMPLE
        Get-CloudPCServicePlan | Format-Table DisplayName,Type,VCpuCount,RamGB,StorageGB

    .EXAMPLE
        Get-CloudPCServicePlan -Type enterprise |
            Sort-Object VCpuCount,RamGB,StorageGB

    .EXAMPLE
        Get-CloudPCServicePlan -DisplayName 'Cloud PC Enterprise 4vCPU/16GB/128GB'
    #>
    [CmdletBinding()]
    [OutputType('WindowsCloudPC.ServicePlan')]
    param(
        [Alias('Name','ServicePlanName')]
        [string]$DisplayName,

        [ValidateSet('enterprise','business')]
        [string]$Type
    )

    begin {
        Connect-CloudPC | Out-Null
    }

    process {
        $uri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/servicePlans'

        Invoke-GraphPaged -Uri $uri | ForEach-Object {
            $plan = $_

            if ($DisplayName -and $plan.displayName -ne $DisplayName) { return }
            if ($Type -and $plan.type -ne $Type) { return }

            [pscustomobject]@{
                PSTypeName     = 'WindowsCloudPC.ServicePlan'
                Id             = $plan.id
                DisplayName    = $plan.displayName
                Type           = $plan.type
                VCpuCount      = $plan.vCpuCount
                RamGB          = $plan.ramInGB
                StorageGB      = $plan.storageInGB
                UserProfileGB  = $plan.userProfileInGB
                Raw            = $plan
            }
        }
    }
}
