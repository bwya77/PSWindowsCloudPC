BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CloudPCUsage' {

    BeforeAll {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }

        Mock -ModuleName WindowsCloudPC Resolve-CloudPCUser -ParameterFilter { $IdOrUpn -eq 'brad@example.com' } -MockWith {
            [pscustomobject]@{ Id = 'uid-brad'; Upn = 'brad@example.com'; DisplayName = 'Bradley Wyatt' }
        }
        Mock -ModuleName WindowsCloudPC Resolve-CloudPCUser -ParameterFilter { $IdOrUpn -eq 'uid-alice' } -MockWith {
            [pscustomobject]@{ Id = 'uid-alice'; Upn = 'alice@example.com'; DisplayName = 'Alice Example' }
        }
    }

    Context 'Shared Cloud PC' {
        BeforeAll {
            $script:SharedInUse = [pscustomobject]@{
                PSTypeName             = 'WindowsCloudPC.CloudPC'
                Id                     = 'cpc-shared-1'
                Name                   = 'CPC-SHARED-01'
                ProvisioningType       = 'Shared'
                ProvisioningPolicyName = 'Shared Policy'
                ProvisioningStatus     = 'provisioned'
                AssignedUserUpn        = 'brad@example.com'
                ConnectivityStatus     = 'inUse'
                SessionStartDateTime   = (Get-Date)
                ManagedDeviceId        = 'mdm-shared-1'
            }
            $script:SharedAvailable = [pscustomobject]@{
                PSTypeName             = 'WindowsCloudPC.CloudPC'
                Id                     = 'cpc-shared-2'
                Name                   = 'CPC-SHARED-02'
                ProvisioningType       = 'Shared'
                ProvisioningPolicyName = 'Shared Policy'
                ProvisioningStatus     = 'provisioned'
                AssignedUserUpn        = $null
                ConnectivityStatus     = 'available'
                SessionStartDateTime   = $null
                ManagedDeviceId        = 'mdm-shared-2'
            }
        }

        It 'reports inUse from connectivityResult' {
            ($SharedInUse | Get-CloudPCUsage).UsageStatus | Should -Be 'inUse'
        }

        It 'reports available from connectivityResult' {
            ($SharedAvailable | Get-CloudPCUsage).UsageStatus | Should -Be 'available'
        }

        It 'resolves the assigned user display name' {
            ($SharedInUse | Get-CloudPCUsage).CurrentUserDisplayName | Should -Be 'Bradley Wyatt'
        }

        It 'emits a WindowsCloudPC.CloudPCUsage object' {
            ($SharedInUse | Get-CloudPCUsage).PSObject.TypeNames | Should -Contain 'WindowsCloudPC.CloudPCUsage'
        }
    }

    Context 'Dedicated Cloud PC' {
        BeforeAll {
            Mock -ModuleName WindowsCloudPC Get-CloudPCManagedDevice -ParameterFilter { $ManagedDeviceId -eq 'mdm-dedicated' } -MockWith {
                @{
                    userPrincipalName = 'alice@example.com'
                    userDisplayName   = 'Alice Example'
                    usersLoggedOn     = @(
                        @{ userId = 'uid-alice'; lastLogOnDateTime = (Get-Date).ToUniversalTime().AddHours(-3).ToString('o') }
                    )
                }
            }

            Mock -ModuleName WindowsCloudPC Get-CloudPCManagedDevice -ParameterFilter { $ManagedDeviceId -eq 'mdm-dedicated-empty' } -MockWith {
                @{
                    userPrincipalName = 'alice@example.com'
                    userDisplayName   = 'Alice Example'
                    usersLoggedOn     = @()
                }
            }

            $script:DedicatedActiveGraphSaysAvailable = [pscustomobject]@{
                PSTypeName         = 'WindowsCloudPC.CloudPC'
                Id                 = 'cpc-dedicated-1'
                Name               = 'CPC-DEDICATED-ACTIVE'
                ProvisioningType   = 'Dedicated'
                AssignedUserUpn    = 'alice@example.com'
                ConnectivityStatus = 'available'   # Graph rarely flips dedicated PCs to inUse
                ManagedDeviceId    = 'mdm-dedicated'
            }
            $script:DedicatedActiveGraphSaysInUse = [pscustomobject]@{
                PSTypeName         = 'WindowsCloudPC.CloudPC'
                Id                 = 'cpc-dedicated-2'
                Name               = 'CPC-DEDICATED-EXPLICIT'
                ProvisioningType   = 'Dedicated'
                AssignedUserUpn    = 'alice@example.com'
                ConnectivityStatus = 'inUse'
                ManagedDeviceId    = 'mdm-dedicated'
            }
            $script:DedicatedIdle = [pscustomobject]@{
                PSTypeName         = 'WindowsCloudPC.CloudPC'
                Id                 = 'cpc-dedicated-3'
                Name               = 'CPC-DEDICATED-IDLE'
                ProvisioningType   = 'Dedicated'
                AssignedUserUpn    = 'alice@example.com'
                ConnectivityStatus = 'available'
                ManagedDeviceId    = 'mdm-dedicated-empty'
            }
            $script:DedicatedUnavailable = [pscustomobject]@{
                PSTypeName         = 'WindowsCloudPC.CloudPC'
                Id                 = 'cpc-dedicated-4'
                Name               = 'CPC-DEDICATED-OFFLINE'
                ProvisioningType   = 'Dedicated'
                AssignedUserUpn    = 'alice@example.com'
                ConnectivityStatus = 'unavailable'
                ManagedDeviceId    = 'mdm-dedicated'
            }
        }

        It 'reports inUse when a user is signed in, even if Graph says available' {
            # Regression: Graph's connectivityResult.status rarely flips dedicated PCs to inUse,
            # so we promote based on managedDevice.usersLoggedOn[] instead.
            ($DedicatedActiveGraphSaysAvailable | Get-CloudPCUsage).UsageStatus | Should -Be 'inUse'
        }

        It 'reports inUse when Graph already says inUse' {
            ($DedicatedActiveGraphSaysInUse | Get-CloudPCUsage).UsageStatus | Should -Be 'inUse'
        }

        It 'reports available when usersLoggedOn is empty' {
            ($DedicatedIdle | Get-CloudPCUsage).UsageStatus | Should -Be 'available'
        }

        It 'preserves unavailable even when usersLoggedOn has a stale entry' {
            # An offline PC is offline regardless of cached logon history.
            ($DedicatedUnavailable | Get-CloudPCUsage).UsageStatus | Should -Be 'unavailable'
        }

        It 'enriches CurrentUserDisplayName from the managedDevice usersLoggedOn[]' {
            ($DedicatedActiveGraphSaysAvailable | Get-CloudPCUsage).CurrentUserDisplayName | Should -Be 'Alice Example'
        }

        It 'reports unknown when ConnectivityStatus is missing and there is no managedDevice' {
            $pc = [pscustomobject]@{
                PSTypeName         = 'WindowsCloudPC.CloudPC'
                Id                 = 'cpc-dedicated-5'
                Name               = 'CPC-DEDICATED-NEW'
                ProvisioningType   = 'Dedicated'
                ConnectivityStatus = $null
                ManagedDeviceId    = $null
            }
            ($pc | Get-CloudPCUsage).UsageStatus | Should -Be 'unknown'
        }
    }
}
