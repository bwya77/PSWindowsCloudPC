BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CloudPCProvisioningPolicy' {

    BeforeAll {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }

        Mock -ModuleName WindowsCloudPC Resolve-CloudPCGroup -ParameterFilter { $GroupId -eq 'grp-frontline' } -MockWith {
            [pscustomobject]@{ Id = 'grp-frontline'; DisplayName = 'Frontline Users' }
        }

        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest -ParameterFilter { $Uri -match 'provisioningPolicies' } -MockWith {
            @{
                value = @(
                    @{
                        id                       = 'pol-shared'
                        displayName              = 'W365-Flex-Shared'
                        description              = 'Frontline shared'
                        provisioningType         = 'sharedByEntraGroup'
                        imageDisplayName         = 'Windows 11 Enterprise'
                        imageType                = 'gallery'
                        enableSingleSignOn       = $true
                        localAdminEnabled        = $false
                        cloudPcNamingTemplate    = 'CFS-%RAND:9%'
                        cloudPcGroupDisplayName  = 'Cloud PC Frontline'
                        managedBy                = 'windows365'
                        gracePeriodInHours       = 1
                        domainJoinConfigurations = @(@{ domainJoinType = 'azureADJoin' })
                        assignments              = @(
                            @{ target = @{ '@odata.type' = '#microsoft.graph.cloudPcManagementGroupAssignmentTarget'; groupId = 'grp-frontline' } }
                        )
                    }
                )
            }
        }
    }

    It 'returns WindowsCloudPC.ProvisioningPolicy objects' {
        $r = Get-CloudPCProvisioningPolicy
        $r | Should -HaveCount 1
        $r[0].PSObject.TypeNames | Should -Contain 'WindowsCloudPC.ProvisioningPolicy'
    }

    It 'mirrors Id into ProvisioningPolicyId for pipeline binding' {
        $p = Get-CloudPCProvisioningPolicy
        $p.ProvisioningPolicyId | Should -Be $p.Id
    }

    It 'resolves assignment group display names' {
        (Get-CloudPCProvisioningPolicy).AssignedGroupNames | Should -Contain 'Frontline Users'
    }

    It 'preserves the raw Graph payload on .Raw' {
        (Get-CloudPCProvisioningPolicy).Raw | Should -Not -BeNullOrEmpty
    }
}
