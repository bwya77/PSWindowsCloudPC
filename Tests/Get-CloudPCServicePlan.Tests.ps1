BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CloudPCServicePlan' {
    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest {
            @{
                value = @(
                    [pscustomobject]@{
                        id              = 'plan-enterprise-1'
                        displayName     = 'Cloud PC Enterprise 2vCPU/8GB/128GB'
                        type            = 'enterprise'
                        vCpuCount       = 2
                        ramInGB         = 8
                        storageInGB     = 128
                        userProfileInGB = 25
                    }
                    [pscustomobject]@{
                        id              = 'plan-business-1'
                        displayName     = 'Cloud PC Business 4vCPU/16GB/256GB'
                        type            = 'business'
                        vCpuCount       = 4
                        ramInGB         = 16
                        storageInGB     = 256
                        userProfileInGB = 50
                    }
                )
            }
        }
    }

    It 'queries the servicePlans endpoint' {
        Get-CloudPCServicePlan | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and
            $Uri -eq 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/servicePlans'
        }
    }

    It 'returns normalized WindowsCloudPC.ServicePlan objects' {
        $plans = Get-CloudPCServicePlan

        $plans | Should -HaveCount 2
        $plans[0].PSObject.TypeNames | Should -Contain 'WindowsCloudPC.ServicePlan'
        $plans[0].DisplayName | Should -Be 'Cloud PC Enterprise 2vCPU/8GB/128GB'
        $plans[0].VCpuCount | Should -Be 2
        $plans[0].RamGB | Should -Be 8
        $plans[0].StorageGB | Should -Be 128
        $plans[0].UserProfileGB | Should -Be 25
    }

    It 'filters by exact DisplayName client-side' {
        $plans = Get-CloudPCServicePlan -DisplayName 'Cloud PC Business 4vCPU/16GB/256GB'

        $plans | Should -HaveCount 1
        $plans.Id | Should -Be 'plan-business-1'
    }

    It 'filters by Type client-side' {
        $plans = Get-CloudPCServicePlan -Type enterprise

        $plans | Should -HaveCount 1
        $plans.Type | Should -Be 'enterprise'
    }
}
