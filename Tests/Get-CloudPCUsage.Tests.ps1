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

        Mock -ModuleName WindowsCloudPC Get-CloudPCConnectivityHistory -MockWith {
            @(
                [pscustomobject]@{
                    ActivityId    = 'activity-default'
                    EventDateTime = (Get-Date).AddDays(-99)
                    EventType     = 'userConnection'
                    EventName     = 'Connection Finished'
                    EventResult   = 'success'
                    Message       = ''
                    Raw           = @{}
                }
            )
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
                ManagedDeviceId        = 'mdm-shared-1'
                Raw                    = @{
                    connectivityResult = @{ status = 'available' }
                    sharedDeviceDetail = @{ sessionStartDateTime = (Get-Date).ToString('o') }
                }
            }

            Mock -ModuleName WindowsCloudPC Get-CloudPCConnectivityHistory -ParameterFilter { $CloudPcId -eq 'cpc-shared-1' } -MockWith {
                @(
                    [pscustomobject]@{
                        ActivityId    = 'activity-shared'
                        EventDateTime = (Get-Date)
                        EventType     = 'userConnection'
                        EventName     = 'Connection Started'
                        EventResult   = 'success'
                        Message       = ''
                        Raw           = @{}
                    }
                )
            }
        }

        It 'reports the shared endpoint connectivityResult' {
            ($SharedPc | Get-CloudPCUsage).UsageStatus | Should -Be 'available'
        }

        It 'maps shared available endpoint status to NotSignedIn' {
            ($SharedPc | Get-CloudPCUsage).SignInStatus | Should -Be 'NotSignedIn'
        }

        It 'uses connectivity history to enrich shared last sign-in time' {
            $result = $SharedPc | Get-CloudPCUsage

            $result.LastActiveTime | Should -BeOfType [datetime]
            $result.DaysSinceLastSignIn | Should -Be 0
            Should -Invoke -ModuleName WindowsCloudPC Get-CloudPCConnectivityHistory -Times 1 -Exactly -ParameterFilter {
                $CloudPcId -eq 'cpc-shared-1'
            }
        }

        It 'does not let delayed shared connectivity history override endpoint status' {
            $pc = [pscustomobject]@{
                PSTypeName             = 'WindowsCloudPC.CloudPC'
                Id                     = 'cpc-shared-1'
                Name                   = 'CPC-SHARED-01'
                ProvisioningType       = 'Shared'
                ProvisioningPolicyName = 'Shared Policy'
                ProvisioningStatus     = 'provisioned'
                AssignedUserUpn        = 'brad@example.com'
                ManagedDeviceId        = 'mdm-shared-1'
                Raw                    = @{
                    connectivityResult = @{ status = 'available' }
                    sharedDeviceDetail = @{ sessionStartDateTime = (Get-Date).ToString('o') }
                }
            }

            $result = $pc | Get-CloudPCUsage
            $result.UsageStatus | Should -Be 'available'
            $result.SignInStatus | Should -Be 'NotSignedIn'
        }

        It 'reports unknown status for shared PCs when endpoint connectivityResult is missing' {
            $pc = [pscustomobject]@{
                PSTypeName             = 'WindowsCloudPC.CloudPC'
                Id                     = 'cpc-shared-1'
                Name                   = 'CPC-SHARED-01'
                ProvisioningType       = 'Shared'
                ProvisioningPolicyName = 'Shared Policy'
                ProvisioningStatus     = 'provisioned'
                AssignedUserUpn        = 'brad@example.com'
                ManagedDeviceId        = 'mdm-shared-1'
                Raw                    = @{
                    connectivityResult = $null
                    sharedDeviceDetail = @{ sessionStartDateTime = (Get-Date).ToString('o') }
                }
            }

            $result = $pc | Get-CloudPCUsage
            $result.UsageStatus | Should -Be 'unknown'
            $result.SignInStatus | Should -BeNullOrEmpty
            $result.LastActiveTime | Should -BeOfType [datetime]
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

            Mock -ModuleName WindowsCloudPC Get-CloudPCConnectivityHistory -ParameterFilter { $CloudPcId -eq 'cpc-dedicated-active' } -MockWith {
                @(
                    [pscustomobject]@{
                        ActivityId    = 'activity-active'
                        EventDateTime = (Get-Date).AddMinutes(-10)
                        EventType     = 'userConnection'
                        EventName     = 'Connection Started'
                        EventResult   = 'success'
                        Message       = ''
                        Raw           = @{}
                    }
                )
            }
            Mock -ModuleName WindowsCloudPC Get-CloudPCConnectivityHistory -ParameterFilter { $CloudPcId -eq 'cpc-dedicated-idle' } -MockWith {
                @(
                    [pscustomobject]@{
                        ActivityId    = 'activity-idle'
                        EventDateTime = (Get-Date).AddDays(-41)
                        EventType     = 'userConnection'
                        EventName     = 'Connection Finished'
                        EventResult   = 'success'
                        Message       = ''
                        Raw           = @{}
                    }
                    [pscustomobject]@{
                        ActivityId    = 'activity-idle'
                        EventDateTime = (Get-Date).AddDays(-42).AddHours(-1)
                        EventType     = 'userConnection'
                        EventName     = 'Connection Started'
                        EventResult   = 'success'
                        Message       = ''
                        Raw           = @{}
                    }
                )
            }
            Mock -ModuleName WindowsCloudPC Get-CloudPCConnectivityHistory -ParameterFilter { $CloudPcId -eq 'cpc-dedicated-nohistory' } -MockWith {
                @()
            }
            Mock -ModuleName WindowsCloudPC Get-CloudPCConnectivityHistory -ParameterFilter { $CloudPcId -eq 'cpc-dedicated-dropped' } -MockWith {
                @(
                    [pscustomobject]@{
                        ActivityId    = 'activity-dropped'
                        EventDateTime = (Get-Date).AddMinutes(-2)
                        EventType     = 'userConnection'
                        EventName     = 'MultipathTransportNetworkDrop'
                        EventResult   = 'failure'
                        Message       = 'Unknown connection error'
                        Raw           = @{}
                    }
                    [pscustomobject]@{
                        ActivityId    = 'activity-dropped'
                        EventDateTime = (Get-Date).AddMinutes(-5)
                        EventType     = 'userConnection'
                        EventName     = 'Connection Started'
                        EventResult   = 'success'
                        Message       = ''
                        Raw           = @{}
                    }
                )
            }

            $script:DedicatedActive = [pscustomobject]@{
                PSTypeName       = 'WindowsCloudPC.CloudPC'
                Id               = 'cpc-dedicated-active'
                Name             = 'CFD-ACTIVE'
                ProvisioningType = 'Dedicated'
                AssignedUserUpn  = 'alice@example.com'
                ManagedDeviceId  = 'mdm-dedicated'
                Raw              = @{ connectivityResult = @{ status = 'available' } }
            }
            $script:DedicatedIdle = [pscustomobject]@{
                PSTypeName       = 'WindowsCloudPC.CloudPC'
                Id               = 'cpc-dedicated-idle'
                Name             = 'CFD-IDLE'
                ProvisioningType = 'Dedicated'
                AssignedUserUpn  = 'alice@example.com'
                ManagedDeviceId  = 'mdm-dedicated'
                Raw              = @{ connectivityResult = @{ status = 'available' } }
            }
            $script:DedicatedNoReport = [pscustomobject]@{
                PSTypeName       = 'WindowsCloudPC.CloudPC'
                Id               = 'cpc-dedicated-nohistory'
                Name             = 'CFD-NOHISTORY'
                ProvisioningType = 'Dedicated'
                AssignedUserUpn  = 'alice@example.com'
                ManagedDeviceId  = 'mdm-dedicated'
                Raw              = @{ connectivityResult = @{ status = 'inUse' } }
            }
            $script:DedicatedDropped = [pscustomobject]@{
                PSTypeName       = 'WindowsCloudPC.CloudPC'
                Id               = 'cpc-dedicated-dropped'
                Name             = 'CFD-DROPPED'
                ProvisioningType = 'Dedicated'
                AssignedUserUpn  = 'alice@example.com'
                ManagedDeviceId  = 'mdm-dedicated'
                Raw              = @{ connectivityResult = @{ status = 'available' } }
            }
        }

        It 'reports inUse from connectivity history' {
            ($DedicatedActive | Get-CloudPCUsage).UsageStatus | Should -Be 'inUse'
        }

        It 'reports available from connectivity history' {
            ($DedicatedIdle | Get-CloudPCUsage).UsageStatus | Should -Be 'available'
        }

        It 'reports available when the latest connection activity has a failure terminal event' {
            ($DedicatedDropped | Get-CloudPCUsage).UsageStatus | Should -Be 'available'
        }

        It 'surfaces DaysSinceLastSignIn for finding idle PCs' {
            ($DedicatedIdle | Get-CloudPCUsage).DaysSinceLastSignIn | Should -Be 42
        }

        It 'falls back to ConnectivityStatus when connectivity history is unavailable' {
            ($DedicatedNoReport | Get-CloudPCUsage).UsageStatus | Should -Be 'inUse'
        }

        It 'enriches CurrentUserDisplayName from managedDevice usersLoggedOn[]' {
            ($DedicatedActive | Get-CloudPCUsage).CurrentUserDisplayName | Should -Be 'Alice Example'
        }
    }
}
