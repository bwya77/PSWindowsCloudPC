function Invoke-CloudPCPolicyReprovision {
    <#
    .SYNOPSIS
        Reprovisions Cloud PCs assigned to a provisioning policy.

    .DESCRIPTION
        Resolves the Cloud PCs associated with a provisioning policy, optionally removes
        excluded Cloud PCs by name, ID, managed device ID, Azure AD device ID, or assigned
        user UPN, then invokes Invoke-CloudPCReprovision for each remaining Cloud PC.

        The cmdlet emits one WindowsCloudPC.PolicyReprovisionResult row per Cloud PC it
        considered, including excluded rows. This makes the target list explicit before
        you rely on the action results.

        Because reprovisioning resets Cloud PCs, this cmdlet supports -WhatIf / -Confirm
        and defaults to ConfirmImpact = 'High'. Use -Force to suppress confirmation prompts
        in automation.

    .PARAMETER ProvisioningPolicyId
        The provisioning policy ID. Accepts pipeline input by property name from
        Get-CloudPCProvisioningPolicy or Get-CloudPCByProvisioningPolicy.

    .PARAMETER ExcludeCloudPC
        Cloud PCs to skip. Match values against Cloud PC Id, Name, ManagedDeviceId,
        AadDeviceId, or AssignedUserUpn. Use this to run against the whole policy except
        a small number of Cloud PCs.

    .PARAMETER OsVersion
        Optional operating system version for reprovisioned Cloud PCs: windows10 or windows11.

    .PARAMETER UserAccountType
        Optional account type for provisioned users: standardUser or administrator.

    .PARAMETER Force
        Suppress confirmation prompts. Equivalent to -Confirm:$false.

    .EXAMPLE
        Invoke-CloudPCPolicyReprovision -ProvisioningPolicyId '8e8a545f-6168-4472-9466-9f05520a5eb3' -WhatIf

        Shows every Cloud PC in the policy that would be reprovisioned.

    .EXAMPLE
        Invoke-CloudPCPolicyReprovision -ProvisioningPolicyId '8e8a545f-6168-4472-9466-9f05520a5eb3' `
            -ExcludeCloudPC 'CPC-KEEP-01','CPC-KEEP-02','cpc-id-3','user4@contoso.com' `
            -OsVersion windows11 -UserAccountType standardUser -Force

        Reprovisions every Cloud PC in the policy except the four specified Cloud PCs.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType('WindowsCloudPC.PolicyReprovisionResult')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [string]$ProvisioningPolicyId,

        [Alias('Exclude','ExcludeId','ExcludeName')]
        [string[]]$ExcludeCloudPC = @(),

        [ValidateSet('windows10','windows11')]
        [string]$OsVersion,

        [ValidateSet('standardUser','administrator')]
        [string]$UserAccountType,

        [switch]$Force
    )

    begin {
        if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = 'None'
        }

        $excludeSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($item in @($ExcludeCloudPC)) {
            if (-not [string]::IsNullOrWhiteSpace($item)) {
                $null = $excludeSet.Add($item.Trim())
            }
        }
    }

    process {
        $policy = Get-CloudPCByProvisioningPolicy -ProvisioningPolicyId $ProvisioningPolicyId
        if (-not $policy) {
            Write-Error "Invoke-CloudPCPolicyReprovision: provisioning policy '$ProvisioningPolicyId' was not found."
            return
        }

        $cloudPcs = @($policy.CloudPCs)
        if ($cloudPcs.Count -eq 0) {
            Write-Error "Invoke-CloudPCPolicyReprovision: provisioning policy '$($policy.DisplayName)' ($ProvisioningPolicyId) has no Cloud PCs."
            return
        }

        foreach ($pc in $cloudPcs) {
            $matchValues = @(
                $pc.Id
                $pc.Name
                $pc.ManagedDeviceId
                $pc.AadDeviceId
                $pc.AssignedUserUpn
            ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

            $excludedBy = $matchValues | Where-Object { $excludeSet.Contains($_) } | Select-Object -First 1
            if ($excludedBy) {
                [pscustomobject]@{
                    PSTypeName             = 'WindowsCloudPC.PolicyReprovisionResult'
                    ProvisioningPolicyId   = $policy.ProvisioningPolicyId
                    ProvisioningPolicyName = $policy.DisplayName
                    CloudPcId              = $pc.Id
                    CloudPcName            = $pc.Name
                    AssignedUserUpn        = $pc.AssignedUserUpn
                    Excluded               = $true
                    ExcludedBy             = $excludedBy
                    Status                 = 'Excluded'
                    RequestedAt            = $null
                    OsVersion              = if ($PSBoundParameters.ContainsKey('OsVersion')) { $OsVersion } else { $null }
                    UserAccountType        = if ($PSBoundParameters.ContainsKey('UserAccountType')) { $UserAccountType } else { $null }
                    ErrorMessage           = $null
                }
                continue
            }

            $target = "Cloud PC '$($pc.Name)' ($($pc.Id)) in policy '$($policy.DisplayName)'"
            if (-not $PSCmdlet.ShouldProcess($target, 'Reprovision')) {
                [pscustomobject]@{
                    PSTypeName             = 'WindowsCloudPC.PolicyReprovisionResult'
                    ProvisioningPolicyId   = $policy.ProvisioningPolicyId
                    ProvisioningPolicyName = $policy.DisplayName
                    CloudPcId              = $pc.Id
                    CloudPcName            = $pc.Name
                    AssignedUserUpn        = $pc.AssignedUserUpn
                    Excluded               = $false
                    ExcludedBy             = $null
                    Status                 = 'WhatIf'
                    RequestedAt            = $null
                    OsVersion              = if ($PSBoundParameters.ContainsKey('OsVersion')) { $OsVersion } else { $null }
                    UserAccountType        = if ($PSBoundParameters.ContainsKey('UserAccountType')) { $UserAccountType } else { $null }
                    ErrorMessage           = $null
                }
                continue
            }

            $invokeParams = @{
                CloudPC  = $pc
                Force    = $true
                PassThru = $true
                Confirm  = $false
            }
            if ($PSBoundParameters.ContainsKey('OsVersion')) {
                $invokeParams.OsVersion = $OsVersion
            }
            if ($PSBoundParameters.ContainsKey('UserAccountType')) {
                $invokeParams.UserAccountType = $UserAccountType
            }

            $result = Invoke-CloudPCReprovision @invokeParams
            [pscustomobject]@{
                PSTypeName             = 'WindowsCloudPC.PolicyReprovisionResult'
                ProvisioningPolicyId   = $policy.ProvisioningPolicyId
                ProvisioningPolicyName = $policy.DisplayName
                CloudPcId              = $pc.Id
                CloudPcName            = $pc.Name
                AssignedUserUpn        = $pc.AssignedUserUpn
                Excluded               = $false
                ExcludedBy             = $null
                Status                 = $result.Status
                RequestedAt            = $result.RequestedAt
                OsVersion              = $result.OsVersion
                UserAccountType        = $result.UserAccountType
                ErrorMessage           = $result.ErrorMessage
            }
        }
    }

    end { }
}

