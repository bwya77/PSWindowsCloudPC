BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Remove-CloudPCProvisioningPolicy' {

    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { }
    }

    It 'requests CloudPC.ReadWrite.All when connecting' {
        Remove-CloudPCProvisioningPolicy -Id 'policy-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Connect-CloudPC -Times 1 -Exactly -ParameterFilter {
            $AdditionalScopes -contains 'CloudPC.ReadWrite.All'
        }
    }

    It 'deletes a provisioning policy by id' {
        Remove-CloudPCProvisioningPolicy -Id 'policy-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'DELETE' -and
            $Uri -eq 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies/policy-1'
        }
    }

    It 'accepts provisioning policy objects from the pipeline' {
        [pscustomobject]@{
            PSTypeName  = 'WindowsCloudPC.ProvisioningPolicy'
            Id          = 'policy-1'
            DisplayName = 'Copied Policy'
        } | Remove-CloudPCProvisioningPolicy -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*/provisioningPolicies/policy-1'
        }
    }

    It 'returns delete result metadata with PassThru' {
        $result = Remove-CloudPCProvisioningPolicy -Id 'policy-1' -Force -Confirm:$false -PassThru

        $result.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.ProvisioningPolicyRemoveResult'
        $result.Id | Should -Be 'policy-1'
        $result.Status | Should -Be 'Deleted'
        $result.ErrorMessage | Should -BeNullOrEmpty
    }

    It 'does not call Graph when WhatIf is passed' {
        $result = Remove-CloudPCProvisioningPolicy -Id 'policy-1' -WhatIf -PassThru

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
        $result.Status | Should -Be 'WhatIf'
    }

    It 'returns failure metadata when Graph rejects the delete' {
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { throw 'policy in use' }

        $result = Remove-CloudPCProvisioningPolicy -Id 'policy-1' -Force -Confirm:$false -PassThru -ErrorAction SilentlyContinue

        $result.Status | Should -Be 'Failed'
        $result.ErrorMessage | Should -BeLike '*policy in use*'
    }
}

