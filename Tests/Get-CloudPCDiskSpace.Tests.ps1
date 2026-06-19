BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CloudPCDiskSpace' {

    BeforeAll {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }

        Mock -ModuleName WindowsCloudPC Get-CloudPC -MockWith {
            @(
                [pscustomobject]@{
                    PSTypeName             = 'WindowsCloudPC.CloudPC'
                    Id                     = 'cpc-1'
                    Name                   = 'CPC-USER-01'
                    ProvisioningType       = 'Dedicated'
                    ProvisioningPolicyName = 'W365-Enterprise-Dev'
                    AssignedUserUpn        = 'user@contoso.com'
                    ManagedDeviceId        = 'mdm-1'
                    Raw                    = @{
                        managedDeviceName = 'CPC-USER-01'
                        displayName       = 'Cloud PC One'
                    }
                },
                [pscustomobject]@{
                    PSTypeName             = 'WindowsCloudPC.CloudPC'
                    Id                     = 'cpc-2'
                    Name                   = 'CPC-SHARED-01'
                    ProvisioningType       = 'Shared'
                    ProvisioningPolicyName = 'W365-Shared'
                    AssignedUserUpn        = $null
                    ManagedDeviceId        = 'mdm-2'
                    Raw                    = @{
                        managedDeviceName = 'CPC-SHARED-01'
                        displayName       = 'Cloud PC Two'
                    }
                }
            )
        }

        Mock -ModuleName WindowsCloudPC Get-CloudPCManagedDevice -ParameterFilter { $ManagedDeviceId -eq 'mdm-1' } -MockWith {
            @{
                id                         = 'mdm-1'
                deviceName                 = 'CPC-USER-01'
                totalStorageSpaceInBytes   = 136844410880
                freeStorageSpaceInBytes    = 95460261888
                lastSyncDateTime           = '2026-06-19T16:30:00Z'
            }
        }

        Mock -ModuleName WindowsCloudPC Get-CloudPCManagedDevice -ParameterFilter { $ManagedDeviceId -eq 'mdm-2' } -MockWith {
            @{
                id                         = 'mdm-2'
                deviceName                 = 'CPC-SHARED-01'
                totalStorageSpaceInBytes   = 274283364352
                freeStorageSpaceInBytes    = 222822400000
                lastSyncDateTime           = '2026-06-19T15:30:00Z'
            }
        }
    }

    It 'returns disk space for all Cloud PCs' {
        $result = Get-CloudPCDiskSpace

        $result | Should -HaveCount 2
        $result[0].PSObject.TypeNames | Should -Contain 'WindowsCloudPC.CloudPCDiskSpace'
    }

    It 'calculates total, free, used, and percent values in GB' {
        $result = Get-CloudPCDiskSpace -CloudPC 'cpc-1'

        $result.TotalStorageGB | Should -Be 127.45
        $result.FreeStorageGB | Should -Be 88.9
        $result.UsedStorageGB | Should -Be 38.54
        $result.PercentFree | Should -Be 69.8
        $result.PercentUsed | Should -Be 30.2
    }

    It 'resolves Cloud PC names passed to -CloudPC' {
        $result = Get-CloudPCDiskSpace -CloudPC 'CPC-SHARED-01'

        $result.CloudPcId | Should -Be 'cpc-2'
        $result.ManagedDeviceId | Should -Be 'mdm-2'
    }

    It 'accepts typed Cloud PC pipeline input' {
        $pc = [pscustomobject]@{
            PSTypeName             = 'WindowsCloudPC.CloudPC'
            Id                     = 'cpc-1'
            Name                   = 'CPC-USER-01'
            ProvisioningType       = 'Dedicated'
            ProvisioningPolicyName = 'W365-Enterprise-Dev'
            AssignedUserUpn        = 'user@contoso.com'
            ManagedDeviceId        = 'mdm-1'
            Raw                    = @{ managedDeviceName = 'CPC-USER-01' }
        }

        $result = $pc | Get-CloudPCDiskSpace

        $result.CloudPcName | Should -Be 'CPC-USER-01'
        Should -Invoke -ModuleName WindowsCloudPC Get-CloudPCManagedDevice -Times 1 -Exactly -ParameterFilter {
            $ManagedDeviceId -eq 'mdm-1'
        }
    }

    It 'rejects unresolved Cloud PC IDs or names' {
        { Get-CloudPCDiskSpace -CloudPC 'missing-cpc' } |
            Should -Throw -ExpectedMessage "*Could not find a Cloud PC matching 'missing-cpc'*"
    }
}
