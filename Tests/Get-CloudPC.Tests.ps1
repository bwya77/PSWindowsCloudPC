BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CloudPC' {

    BeforeAll {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest {
            @{
                value = @(
                    @{
                        id                     = 'cpc-shared-1'
                        managedDeviceId        = 'mdm-shared-1'
                        managedDeviceName      = 'CPC-SHARED-01'
                        displayName            = 'Shared Cloud PC Display'
                        status                 = 'provisioned'
                        provisioningType       = 'sharedByEntraGroup'
                        provisioningPolicyId   = 'pol-shared'
                        provisioningPolicyName = 'Shared Policy'
                        servicePlanName        = 'Frontline'
                        userPrincipalName      = $null
                        sharedDeviceDetail     = @{
                            assignedToUserPrincipalName = 'brad@example.com'
                            sessionStartDateTime        = '2026-06-15T18:00:00Z'
                        }
                        connectivityResult     = @{ status = 'inUse' }
                        lastModifiedDateTime   = '2026-06-15T18:00:00Z'
                        aadDeviceId            = 'aad-shared-1'
                    },
                    @{
                        id                     = 'cpc-dedicated-1'
                        managedDeviceId        = 'mdm-dedicated-1'
                        managedDeviceName      = 'CPC-DEDICATED-01'
                        displayName            = 'Dedicated Cloud PC Display'
                        status                 = 'provisioned'
                        provisioningType       = 'dedicated'
                        provisioningPolicyId   = 'pol-dedicated'
                        provisioningPolicyName = 'Dedicated Policy'
                        servicePlanName        = 'Enterprise'
                        userPrincipalName      = 'alice@example.com'
                        sharedDeviceDetail     = $null
                        connectivityResult     = @{ status = 'available' }
                        lastModifiedDateTime   = '2026-06-15T17:00:00Z'
                        aadDeviceId            = 'aad-dedicated-1'
                    }
                )
            }
        } -ParameterFilter {
            $Uri -like 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs?*'
        }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest {
            @{
                id                     = 'cpc-dedicated-1'
                managedDeviceId        = 'mdm-dedicated-1'
                managedDeviceName      = 'CPC-DEDICATED-01'
                displayName            = 'Dedicated Cloud PC Display'
                status                 = 'provisioned'
                provisioningType       = 'dedicated'
                provisioningPolicyId   = 'pol-dedicated'
                provisioningPolicyName = 'Dedicated Policy'
                servicePlanName        = 'Enterprise'
                userPrincipalName      = 'alice@example.com'
                sharedDeviceDetail     = $null
                connectivityResult     = @{ status = 'available' }
                lastModifiedDateTime   = '2026-06-15T17:00:00Z'
                aadDeviceId            = 'aad-dedicated-1'
            }
        } -ParameterFilter {
            $Uri -like 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/cpc-dedicated-1?*'
        }
    }

    It 'returns objects typed as WindowsCloudPC.CloudPC' {
        $r = Get-CloudPC
        $r | Should -HaveCount 2
        $r[0].PSObject.TypeNames | Should -Contain 'WindowsCloudPC.CloudPC'
    }

    It 'normalizes sharedByEntraGroup -> Shared' {
        (Get-CloudPC | Where-Object Id -eq 'cpc-shared-1').ProvisioningType | Should -Be 'Shared'
    }

    It 'normalizes dedicated -> Dedicated' {
        (Get-CloudPC | Where-Object Id -eq 'cpc-dedicated-1').ProvisioningType | Should -Be 'Dedicated'
    }

    It 'filters with -Type Shared' {
        $r = Get-CloudPC -Type Shared
        $r | Should -HaveCount 1
        $r.ProvisioningType | Should -Be 'Shared'
    }

    It 'filters with -Type Dedicated' {
        $r = Get-CloudPC -Type Dedicated
        $r | Should -HaveCount 1
        $r.ProvisioningType | Should -Be 'Dedicated'
    }

    It 'derives AssignedUserUpn from sharedDeviceDetail for shared PCs' {
        (Get-CloudPC -Type Shared).AssignedUserUpn | Should -Be 'brad@example.com'
    }

    It 'derives AssignedUserUpn from userPrincipalName for dedicated PCs' {
        (Get-CloudPC -Type Dedicated).AssignedUserUpn | Should -Be 'alice@example.com'
    }

    It 'uses displayName for Name and preserves managedDeviceName separately' {
        $pc = Get-CloudPC | Where-Object Id -eq 'cpc-dedicated-1'

        $pc.Name | Should -Be 'Dedicated Cloud PC Display'
        $pc.DisplayName | Should -Be 'Dedicated Cloud PC Display'
        $pc.ManagedDeviceName | Should -Be 'CPC-DEDICATED-01'
    }

    It 'preserves the raw Graph payload on .Raw' {
        (Get-CloudPC | Select-Object -First 1).Raw | Should -Not -BeNullOrEmpty
    }

    It 'requests evolvable connectivityResult enum values' {
        Get-CloudPC | Out-Null
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -ParameterFilter {
            $Headers.Prefer -eq 'include-unknown-enum-members'
        }
    }

    It 'accepts ProvisioningPolicyId from pipeline by property name' {
        $piped = [pscustomobject]@{ ProvisioningPolicyId = 'pol-shared' } | Get-CloudPC
        $piped | Should -Not -BeNullOrEmpty
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -ParameterFilter {
            $Uri -match 'pol-shared'
        }
    }

    It 'gets a single Cloud PC by Id' {
        $pc = Get-CloudPC -Id 'cpc-dedicated-1'

        $pc.Id | Should -Be 'cpc-dedicated-1'
        $pc.Name | Should -Be 'Dedicated Cloud PC Display'
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and
            $Uri -like 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/cpc-dedicated-1?*'
        }
    }

    It 'filters by exact display name' {
        $pc = Get-CloudPC -Name 'Dedicated Cloud PC Display'

        $pc | Should -HaveCount 1
        $pc.Id | Should -Be 'cpc-dedicated-1'
    }

    It 'filters by exact managed device name' {
        $pc = Get-CloudPC -Name 'CPC-DEDICATED-01'

        $pc | Should -HaveCount 1
        $pc.DisplayName | Should -Be 'Dedicated Cloud PC Display'
    }

    It 'supports wildcard name searches' {
        $pcs = Get-CloudPC -Name '*Cloud PC Display'

        $pcs | Should -HaveCount 2
        $pcs.Id | Should -Contain 'cpc-shared-1'
        $pcs.Id | Should -Contain 'cpc-dedicated-1'
    }

    It 'adds ProvisioningStatus to the Graph filter' {
        Get-CloudPC -ProvisioningStatus inGracePeriod | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -ParameterFilter {
            $Uri -match 'inGracePeriod'
        }
    }

    It 'supports multiple ProvisioningStatus values' {
        Get-CloudPC -ProvisioningStatus inGracePeriod,deprovisioning | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -ParameterFilter {
            $Uri -match 'inGracePeriod' -and
            $Uri -match 'deprovisioning'
        }
    }

    It 'rejects using Id and Name together' {
        { Get-CloudPC -Id 'cpc-dedicated-1' -Name 'Dedicated Cloud PC Display' } |
            Should -Throw -ExpectedMessage '*use either -Id or -Name*'
    }
}
