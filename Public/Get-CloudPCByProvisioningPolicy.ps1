function Get-CloudPCByProvisioningPolicy {
    <#
    .SYNOPSIS
        Groups Cloud PCs under their provisioning policies and returns one row per policy.

    .DESCRIPTION
        Fetches Cloud PCs with Get-CloudPC and groups them by ProvisioningPolicyId, returning
        one PSCustomObject per policy (PSTypeName = 'WindowsCloudPC.ProvisioningPolicyCloudPCs')
        with a CloudPCCount and a CloudPCs array of the matching Get-CloudPC objects.

        Useful for answering "how many Cloud PCs are on each policy" and "which Cloud PCs
        belong to which policy" without leaving stale/null fields on the policy object itself.

        Empty policies (policies with zero Cloud PCs provisioned) are included with
        CloudPCCount = 0 and CloudPCs = @() so you can spot drift.

    .PARAMETER ProvisioningPolicyId
        Optional: scope the result to a single policy. Accepts pipeline input by property
        name from Get-CloudPCProvisioningPolicy.

    .EXAMPLE
        Get-CloudPCByProvisioningPolicy | Format-Table DisplayName,ProvisioningType,CloudPCCount

    .EXAMPLE
        Get-CloudPCByProvisioningPolicy |
            Select-Object DisplayName -ExpandProperty CloudPCs |
            Format-Table DisplayName,Name,ProvisioningStatus

    .EXAMPLE
        Get-CloudPCProvisioningPolicy -Id 8e8a545f-6168-4472-9466-9f05520a5eb3 |
            Get-CloudPCByProvisioningPolicy
    #>
    [CmdletBinding()]
    [OutputType('WindowsCloudPC.ProvisioningPolicyCloudPCs')]
    param(
        [Parameter(Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [string]$ProvisioningPolicyId
    )

    begin {
        Connect-CloudPC | Out-Null
        $piped = $false
        $ids   = [System.Collections.Generic.List[string]]@()
    }

    process {
        if ($ProvisioningPolicyId) {
            $piped = $true
            $ids.Add($ProvisioningPolicyId)
        }
    }

    end {
        $policies = if ($piped) {
            foreach ($id in $ids) { Get-CloudPCProvisioningPolicy -Id $id }
        }
        else {
            Get-CloudPCProvisioningPolicy
        }

        # Fetch CloudPCs once per policy (Graph supports a per-policy filter so this is
        # cheaper than pulling the full estate when only one policy was requested).
        foreach ($p in $policies) {
            $cpcs = @( Get-CloudPC -ProvisioningPolicyId $p.Id )

            [pscustomobject]@{
                PSTypeName              = 'WindowsCloudPC.ProvisioningPolicyCloudPCs'
                Id                      = $p.Id
                ProvisioningPolicyId    = $p.Id
                DisplayName             = $p.DisplayName
                ProvisioningType        = $p.ProvisioningType
                ImageDisplayName        = $p.ImageDisplayName
                AssignedGroupNames      = $p.AssignedGroupNames
                CloudPCCount            = $cpcs.Count
                CloudPCs                = $cpcs
            }
        }
    }
}
