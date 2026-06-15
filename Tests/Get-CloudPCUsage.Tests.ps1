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

        # Default: real-time report says "no one signed in".
        Mock -ModuleName WindowsCloudPC Get-CloudPCRealTimeStatus -MockWith {
            [pscustomobject]@{
                ManagedDeviceName   = 'unused'
                CloudPcId           = $CloudPcId
                DaysSinceLastSignIn = 99
                SignInStatus        = 'NotSignedIn'
                LastActiveTime      = (Get-Date).AddDays(-99)
                Raw                 = @{}
            }
        }
    }

    Context 'Parameter binding' {
        It 'rejects a plain string passed to -CloudPC' {
            { Get-CloudPCUsage -CloudPC 'test' } | Should -Throw -ExpectedMessage '*WindowsCloudPC.CloudPC*'
        }

        It 'rejects an arbitrary hashtable passed to -CloudPC' {
            { Get-CloudPCUsage -CloudPC ([pscustomobject]@{ Id = 'x' }) } |
                Should -Throw -ExpectedMessage '*WindowsCloudPC.CloudPC*'
        }

        It 'accepts a typed WindowsCloudPC.CloudPC object' {
            $pc = [pscustomobject]@{
                PSTypeName       = 'WindowsCloudPC.CloudPC'
                Id               = 'cpc-1'
                Name             = 'CPC-1'
                ProvisioningType = 'Shared'
                AssignedUserUpn  = 'brad@example.com'
            }
            { Get-CloudPCUsage -CloudPC $pc } | Should -Not -Throw
        }
    }

    Context 'Shared Cloud PC' {
        BeforeAll {
            $script:SharedPc = [pscustomobject]@{
                PSTypeName             = 'WindowsCloudPC.CloudPC'
                Id                     = 'cpc-shared-1'
                Name                   = 'CPC-SHARED-01'
                ProvisioningType       = 'Shared'
                ProvisioningPolicyName = 'Shared Policy'
                ProvisioningStatus     = 'provisioned'
                AssignedUserUpn        = 'brad@example.com'
                ConnectivityStatus     = 'available'
                SessionStartDateTime   = (Get-Date)
                ManagedDeviceId        = 'mdm-shared-1'
            }

            Mock -ModuleName WindowsCloudPC Get-CloudPCRealTimeStatus -ParameterFilter { $CloudPcId -eq 'cpc-shared-1' } -MockWith {
                [pscustomobject]@{
                    ManagedDeviceName   = 'CPC-SHARED-01'
                    CloudPcId           = 'cpc-shared-1'
                    DaysSinceLastSignIn = 0
                    SignInStatus        = 'SignedIn'
                    LastActiveTime      = (Get-Date)
                    Raw                 = @{}
                }
            }
        }

        It 'reports inUse when the real-time report says SignedIn' {
            ($SharedPc | Get-CloudPCUsage).UsageStatus | Should -Be 'inUse'
        }

        It 'surfaces SignInStatus on the output object' {
            ($SharedPc | Get-CloudPCUsage).SignInStatus | Should -Be 'SignedIn'
        }

        It 'surfaces LastActiveTime on the output object' {
            ($SharedPc | Get-CloudPCUsage).LastActiveTime | Should -BeOfType [datetime]
        }

        It 'resolves the assigned user display name' {
            ($SharedPc | Get-CloudPCUsage).CurrentUserDisplayName | Should -Be 'Bradley Wyatt'
        }

        It 'emits a WindowsCloudPC.CloudPCUsage object' {
            ($SharedPc | Get-CloudPCUsage).PSObject.TypeNames | Should -Contain 'WindowsCloudPC.CloudPCUsage'
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

            Mock -ModuleName WindowsCloudPC Get-CloudPCRealTimeStatus -ParameterFilter { $CloudPcId -eq 'cpc-dedicated-active' } -MockWith {
                [pscustomobject]@{
                    ManagedDeviceName   = 'CFD-ACTIVE'
                    CloudPcId           = 'cpc-dedicated-active'
                    DaysSinceLastSignIn = 0
                    SignInStatus        = 'SignedIn'
                    LastActiveTime      = (Get-Date)
                    Raw                 = @{}
                }
            }
            Mock -ModuleName WindowsCloudPC Get-CloudPCRealTimeStatus -ParameterFilter { $CloudPcId -eq 'cpc-dedicated-idle' } -MockWith {
                [pscustomobject]@{
                    ManagedDeviceName   = 'CFD-IDLE'
                    CloudPcId           = 'cpc-dedicated-idle'
                    DaysSinceLastSignIn = 42
                    SignInStatus        = 'NotSignedIn'
                    LastActiveTime      = (Get-Date).AddDays(-42)
                    Raw                 = @{}
                }
            }
            Mock -ModuleName WindowsCloudPC Get-CloudPCRealTimeStatus -ParameterFilter { $CloudPcId -eq 'cpc-dedicated-noreport' } -MockWith { $null }

            $script:DedicatedActive = [pscustomobject]@{
                PSTypeName         = 'WindowsCloudPC.CloudPC'
                Id                 = 'cpc-dedicated-active'
                Name               = 'CFD-ACTIVE'
                ProvisioningType   = 'Dedicated'
                AssignedUserUpn    = 'alice@example.com'
                ConnectivityStatus = 'available'
                ManagedDeviceId    = 'mdm-dedicated'
            }
            $script:DedicatedIdle = [pscustomobject]@{
                PSTypeName         = 'WindowsCloudPC.CloudPC'
                Id                 = 'cpc-dedicated-idle'
                Name               = 'CFD-IDLE'
                ProvisioningType   = 'Dedicated'
                AssignedUserUpn    = 'alice@example.com'
                ConnectivityStatus = 'available'
                ManagedDeviceId    = 'mdm-dedicated'
            }
            $script:DedicatedNoReport = [pscustomobject]@{
                PSTypeName         = 'WindowsCloudPC.CloudPC'
                Id                 = 'cpc-dedicated-noreport'
                Name               = 'CFD-NOREPORT'
                ProvisioningType   = 'Dedicated'
                AssignedUserUpn    = 'alice@example.com'
                ConnectivityStatus = 'inUse'
                ManagedDeviceId    = 'mdm-dedicated'
            }
        }

        It 'reports inUse from the real-time report' {
            ($DedicatedActive | Get-CloudPCUsage).UsageStatus | Should -Be 'inUse'
        }

        It 'reports available from the real-time report' {
            ($DedicatedIdle | Get-CloudPCUsage).UsageStatus | Should -Be 'available'
        }

        It 'surfaces DaysSinceLastSignIn for finding idle PCs' {
            ($DedicatedIdle | Get-CloudPCUsage).DaysSinceLastSignIn | Should -Be 42
        }

        It 'falls back to ConnectivityStatus when the real-time report is unavailable' {
            ($DedicatedNoReport | Get-CloudPCUsage).UsageStatus | Should -Be 'inUse'
        }

        It 'enriches CurrentUserDisplayName from managedDevice usersLoggedOn[]' {
            ($DedicatedActive | Get-CloudPCUsage).CurrentUserDisplayName | Should -Be 'Alice Example'
        }
    }
}
