BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CloudPCByProvisioningPolicy' {

    BeforeAll {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }

        Mock -ModuleName WindowsCloudPC Get-CloudPCProvisioningPolicy -MockWith {
            @(
                [pscustomobject]@{
                    PSTypeName           = 'WindowsCloudPC.ProvisioningPolicy'
                    Id                   = 'pol-shared'
                    ProvisioningPolicyId = 'pol-shared'
                    DisplayName          = 'W365-Flex-Shared'
                    ProvisioningType     = 'sharedByEntraGroup'
                    ImageDisplayName     = 'Windows 11 Enterprise'
                    AssignedGroupNames   = @('Frontline Users')
                }
                [pscustomobject]@{
                    PSTypeName           = 'WindowsCloudPC.ProvisioningPolicy'
                    Id                   = 'pol-dedicated'
                    ProvisioningPolicyId = 'pol-dedicated'
                    DisplayName          = 'W365-Flex-Dedicated'
                    ProvisioningType     = 'sharedByUser'
                    ImageDisplayName     = 'Windows 11 Enterprise'
                    AssignedGroupNames   = @('Dedicated Users')
                }
                [pscustomobject]@{
                    PSTypeName           = 'WindowsCloudPC.ProvisioningPolicy'
                    Id                   = 'pol-empty'
                    ProvisioningPolicyId = 'pol-empty'
                    DisplayName          = 'W365-Empty'
                    ProvisioningType     = 'sharedByUser'
                    ImageDisplayName     = 'Windows 11 Enterprise'
                    AssignedGroupNames   = @()
                }
            )
        }

        Mock -ModuleName WindowsCloudPC Get-CloudPCProvisioningPolicy -ParameterFilter { $Id -eq 'pol-shared' } -MockWith {
            [pscustomobject]@{
                PSTypeName           = 'WindowsCloudPC.ProvisioningPolicy'
                Id                   = 'pol-shared'
                ProvisioningPolicyId = 'pol-shared'
                DisplayName          = 'W365-Flex-Shared'
                ProvisioningType     = 'sharedByEntraGroup'
                ImageDisplayName     = 'Windows 11 Enterprise'
                AssignedGroupNames   = @('Frontline Users')
            }
        }

        Mock -ModuleName WindowsCloudPC Get-CloudPC -ParameterFilter { $ProvisioningPolicyId -eq 'pol-shared' } -MockWith {
            @(
                [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'pc1'; Name = 'CFS-AAA'; ProvisioningPolicyId = 'pol-shared' }
                [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'pc2'; Name = 'CFS-BBB'; ProvisioningPolicyId = 'pol-shared' }
            )
        }
        Mock -ModuleName WindowsCloudPC Get-CloudPC -ParameterFilter { $ProvisioningPolicyId -eq 'pol-dedicated' } -MockWith {
            @(
                [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'pc3'; Name = 'CFD-CCC'; ProvisioningPolicyId = 'pol-dedicated' }
            )
        }
        Mock -ModuleName WindowsCloudPC Get-CloudPC -ParameterFilter { $ProvisioningPolicyId -eq 'pol-empty' } -MockWith { @() }
    }

    It 'returns one row per policy (including empty ones)' {
        (Get-CloudPCByProvisioningPolicy).Count | Should -Be 3
    }

    It 'emits WindowsCloudPC.ProvisioningPolicyCloudPCs typed objects' {
        $r = Get-CloudPCByProvisioningPolicy | Select-Object -First 1
        $r.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.ProvisioningPolicyCloudPCs'
    }

    It 'sets CloudPCCount to the real count of returned PCs' {
        $r = Get-CloudPCByProvisioningPolicy
        ($r | Where-Object DisplayName -eq 'W365-Flex-Shared').CloudPCCount    | Should -Be 2
        ($r | Where-Object DisplayName -eq 'W365-Flex-Dedicated').CloudPCCount | Should -Be 1
    }

    It 'reports zero for policies with no provisioned PCs' {
        $empty = Get-CloudPCByProvisioningPolicy | Where-Object DisplayName -eq 'W365-Empty'
        $empty.CloudPCCount | Should -Be 0
        ,$empty.CloudPCs | Should -BeOfType [array]
        $empty.CloudPCs.Count | Should -Be 0
    }

    It 'exposes the CloudPC objects on .CloudPCs' {
        $shared = Get-CloudPCByProvisioningPolicy | Where-Object DisplayName -eq 'W365-Flex-Shared'
        $shared.CloudPCs.Name | Should -Be @('CFS-AAA','CFS-BBB')
    }

    It 'scopes results when -ProvisioningPolicyId is passed' {
        $r = Get-CloudPCByProvisioningPolicy -ProvisioningPolicyId 'pol-shared'
        $r | Should -HaveCount 1
        $r.DisplayName | Should -Be 'W365-Flex-Shared'
    }

    It 'accepts ProvisioningPolicyId from pipeline by property name' {
        $r = [pscustomobject]@{ ProvisioningPolicyId = 'pol-shared' } | Get-CloudPCByProvisioningPolicy
        $r | Should -HaveCount 1
        $r.DisplayName | Should -Be 'W365-Flex-Shared'
    }
}
