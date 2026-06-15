function Get-CloudPCProvisioningPolicy {
    <#
    .SYNOPSIS
        Returns Windows 365 Cloud PC provisioning policies, with assigned groups resolved.

    .DESCRIPTION
        Wraps /beta/deviceManagement/virtualEndpoint/provisioningPolicies?$expand=assignments
        and returns normalized PSCustomObjects (PSTypeName = 'WindowsCloudPC.ProvisioningPolicy').

        Each policy exposes a ProvisioningPolicyId property (mirror of Id) so it pipes cleanly
        into Get-CloudPC, Get-CloudPCUsage, and Get-CloudPCByProvisioningPolicy:

            Get-CloudPCProvisioningPolicy | Get-CloudPC
            Get-CloudPCProvisioningPolicy | Get-CloudPCUsage
            Get-CloudPCProvisioningPolicy | Get-CloudPCByProvisioningPolicy

        To see which Cloud PCs belong to which policy (and a count), use
        Get-CloudPCByProvisioningPolicy.

    .PARAMETER Id
        Optional: fetch a single policy by id. Accepts pipeline input by property name
        (binds to Id / ProvisioningPolicyId).

    .EXAMPLE
        Get-CloudPCProvisioningPolicy | Format-Table DisplayName,ProvisioningType,AssignedGroupNames

    .EXAMPLE
        # Usage report grouped by policy
        Get-CloudPCProvisioningPolicy |
            Get-CloudPCUsage |
            Group-Object ProvisioningPolicyName |
            Format-Table Name,Count

    .EXAMPLE
        # Cloud PCs grouped under each policy
        Get-CloudPCByProvisioningPolicy | Format-Table DisplayName,ProvisioningType,CloudPCCount
    #>
    [CmdletBinding()]
    [OutputType('WindowsCloudPC.ProvisioningPolicy')]
    param(
        [Parameter(Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('ProvisioningPolicyId')]
        [string]$Id
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
                Raw                     = $p
            }

            [pscustomobject]$obj
        }
    }

    end { }
}
