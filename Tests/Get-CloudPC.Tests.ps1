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

    It 'preserves the raw Graph payload on .Raw' {
        (Get-CloudPC | Select-Object -First 1).Raw | Should -Not -BeNullOrEmpty
    }

    It 'accepts ProvisioningPolicyId from pipeline by property name' {
        $piped = [pscustomobject]@{ ProvisioningPolicyId = 'pol-shared' } | Get-CloudPC
        $piped | Should -Not -BeNullOrEmpty
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -ParameterFilter {
            $Uri -match 'pol-shared'
        }
    }
}
