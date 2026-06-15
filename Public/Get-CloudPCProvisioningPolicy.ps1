function Get-CloudPCProvisioningPolicy {
    <#
    .SYNOPSIS
        Returns Windows 365 Cloud PC provisioning policies, with assigned groups resolved.

    .DESCRIPTION
        Wraps /beta/deviceManagement/virtualEndpoint/provisioningPolicies?$expand=assignments
        and returns normalized PSCustomObjects (PSTypeName = 'WindowsCloudPC.ProvisioningPolicy').

        Each policy exposes a ProvisioningPolicyId property (mirror of Id) so it pipes cleanly
        into Get-CloudPC and Get-CloudPCUsage:

            Get-CloudPCProvisioningPolicy | Get-CloudPC
            Get-CloudPCProvisioningPolicy | Get-CloudPCUsage

    .PARAMETER Id
        Optional: fetch a single policy by id. Accepts pipeline input by property name
        (binds to Id / ProvisioningPolicyId).

    .PARAMETER IncludeCloudPCCount
        Adds a CloudPCCount property by querying Cloud PCs for each policy.

    .PARAMETER IncludeCloudPCs
        Adds a CloudPCs property containing the full Get-CloudPC objects for each policy.
        Implies -IncludeCloudPCCount.

    .EXAMPLE
        Get-CloudPCProvisioningPolicy | Format-Table DisplayName,ProvisioningType,AssignedGroupNames

    .EXAMPLE
        Get-CloudPCProvisioningPolicy -IncludeCloudPCCount |
            Format-Table DisplayName,ProvisioningType,CloudPCCount

    .EXAMPLE
        # Usage report grouped by policy
        Get-CloudPCProvisioningPolicy |
            Get-CloudPCUsage |
            Group-Object ProvisioningPolicyName |
            Format-Table Name,Count

    .EXAMPLE
        Get-CloudPCProvisioningPolicy -Id 8e8a545f-6168-4472-9466-9f05520a5eb3 -IncludeCloudPCs |
            Select-Object -ExpandProperty CloudPCs
    #>
    [CmdletBinding()]
    [OutputType('WindowsCloudPC.ProvisioningPolicy')]
    param(
        [Parameter(Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('ProvisioningPolicyId')]
        [string]$Id,

        [switch]$IncludeCloudPCCount,

        [switch]$IncludeCloudPCs
    )

    begin {
        Connect-CloudPC | Out-Null
    }

    process {
        if ($Id) {
            $uri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies/$Id`?`$expand=assignments"
            try {
                $policies = @( Invoke-MgGraphRequest -Method GET -Uri $uri )
            }
            catch {
                Write-Error "Provisioning policy '$Id' not found: $($_.Exception.Message)"
                return
            }
        }
        else {
            $uri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies?$expand=assignments'
            $policies = Invoke-GraphPaged -Uri $uri
        }

        foreach ($p in $policies) {
            $assignmentInfo = foreach ($a in @($p.assignments)) {
                $groupId   = $a.target.groupId
                $groupName = if ($groupId) { (Resolve-CloudPCGroup -GroupId $groupId).DisplayName } else { $null }
                [pscustomobject]@{
                    GroupId    = $groupId
                    GroupName  = $groupName
                    TargetType = $a.target.'@odata.type'
                }
            }

            $cpcs     = $null
            $cpcCount = $null
            if ($IncludeCloudPCs -or $IncludeCloudPCCount) {
                $cpcs     = @( Get-CloudPC -ProvisioningPolicyId $p.id )
                $cpcCount = $cpcs.Count
            }

            $domainJoinTypes = @()
            if ($p.domainJoinConfigurations) {
                $domainJoinTypes = $p.domainJoinConfigurations | ForEach-Object { $_.domainJoinType } | Where-Object { $_ }
            }

            $obj = [ordered]@{
                PSTypeName              = 'WindowsCloudPC.ProvisioningPolicy'
                Id                      = $p.id
                ProvisioningPolicyId    = $p.id   # mirror so it pipes cleanly into Get-CloudPC
                DisplayName             = $p.displayName
                Description             = $p.description
                ProvisioningType        = $p.provisioningType
                ImageDisplayName        = $p.imageDisplayName
                ImageType               = $p.imageType
                EnableSingleSignOn      = $p.enableSingleSignOn
                LocalAdminEnabled       = $p.localAdminEnabled
                CloudPcNamingTemplate   = $p.cloudPcNamingTemplate
                CloudPcGroupDisplayName = $p.cloudPcGroupDisplayName
                ManagedBy               = $p.managedBy
                GracePeriodInHours      = $p.gracePeriodInHours
                DomainJoinTypes         = ($domainJoinTypes -join ',')
                Assignments             = $assignmentInfo
                AssignedGroupIds        = @($assignmentInfo | Where-Object { $_.GroupId } | Select-Object -ExpandProperty GroupId)
                AssignedGroupNames      = @($assignmentInfo | Where-Object { $_.GroupName } | Select-Object -ExpandProperty GroupName)
                CloudPCCount            = $cpcCount
                CloudPCs                = $cpcs
                Raw                     = $p
            }

            [pscustomobject]$obj
        }
    }
}
