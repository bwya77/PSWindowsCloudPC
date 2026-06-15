BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CloudPCUsageBeta' {

    BeforeAll {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }

        $script:SignedInPc = [pscustomobject]@{
            PSTypeName             = 'WindowsCloudPC.CloudPC'
            Id                     = 'cpc-signed-in'
            Name                   = 'CFD-ACTIVE'
            ProvisioningType       = 'Dedicated'
            ProvisioningPolicyName = 'W365-Flex-Dedicated'
            ProvisioningStatus     = 'provisioned'
            AssignedUserUpn        = 'brad@example.com'
            ConnectivityStatus     = 'available'
            ManagedDeviceId        = 'mdm-active'
        }
        $script:NotSignedInPc = [pscustomobject]@{
            PSTypeName             = 'WindowsCloudPC.CloudPC'
            Id                     = 'cpc-idle'
            Name                   = 'CFD-IDLE'
            ProvisioningType       = 'Dedicated'
            ProvisioningPolicyName = 'W365-Flex-Dedicated'
            ProvisioningStatus     = 'provisioned'
            AssignedUserUpn        = 'alice@example.com'
            ConnectivityStatus     = 'available'
            ManagedDeviceId        = 'mdm-idle'
        }
        $script:NoReportPc = [pscustomobject]@{
            PSTypeName             = 'WindowsCloudPC.CloudPC'
            Id                     = 'cpc-noreport'
            Name                   = 'CFD-NOREPORT'
            ProvisioningType       = 'Dedicated'
            ConnectivityStatus     = 'inUse'
            ManagedDeviceId        = 'mdm-noreport'
        }

        Mock -ModuleName WindowsCloudPC Get-CloudPCRealTimeStatus -ParameterFilter { $CloudPcId -eq 'cpc-signed-in' } -MockWith {
            [pscustomobject]@{
                ManagedDeviceName   = 'CFD-ACTIVE'
                CloudPcId           = 'cpc-signed-in'
                DaysSinceLastSignIn = 0
                SignInStatus        = 'SignedIn'
                LastActiveTime      = [datetime]'2026-06-15T19:05:40Z'
                Raw                 = @{ Schema = @(); Values = @() }
            }
        }
        Mock -ModuleName WindowsCloudPC Get-CloudPCRealTimeStatus -ParameterFilter { $CloudPcId -eq 'cpc-idle' } -MockWith {
            [pscustomobject]@{
                ManagedDeviceName   = 'CFD-IDLE'
                CloudPcId           = 'cpc-idle'
                DaysSinceLastSignIn = 42
                SignInStatus        = 'NotSignedIn'
                LastActiveTime      = [datetime]'2026-05-04T12:00:00Z'
                Raw                 = @{ Schema = @(); Values = @() }
            }
        }
        Mock -ModuleName WindowsCloudPC Get-CloudPCRealTimeStatus -ParameterFilter { $CloudPcId -eq 'cpc-noreport' } -MockWith { $null }
    }

    It 'maps SignedIn -> inUse' {
        ($SignedInPc | Get-CloudPCUsageBeta).UsageStatus | Should -Be 'inUse'
    }

    It 'maps NotSignedIn -> available' {
        ($NotSignedInPc | Get-CloudPCUsageBeta).UsageStatus | Should -Be 'available'
    }

    It 'falls back to the cloudPC ConnectivityStatus when the report returns nothing' {
        ($NoReportPc | Get-CloudPCUsageBeta).UsageStatus | Should -Be 'inUse'
    }

    It 'surfaces DaysSinceLastSignIn for idle-PC reporting' {
        ($NotSignedInPc | Get-CloudPCUsageBeta).DaysSinceLastSignIn | Should -Be 42
    }

    It 'surfaces LastActiveTime' {
        ($SignedInPc | Get-CloudPCUsageBeta).LastActiveTime | Should -BeOfType [datetime]
    }

    It 'preserves the AssignedUserUpn from the upstream Cloud PC' {
        ($SignedInPc | Get-CloudPCUsageBeta).AssignedUserUpn | Should -Be 'brad@example.com'
    }

    It 'emits a WindowsCloudPC.CloudPCUsageBeta object' {
        ($SignedInPc | Get-CloudPCUsageBeta).PSObject.TypeNames | Should -Contain 'WindowsCloudPC.CloudPCUsageBeta'
    }

    It 'passes through unknown SignInStatus values verbatim' {
        Mock -ModuleName WindowsCloudPC Get-CloudPCRealTimeStatus -ParameterFilter { $CloudPcId -eq 'cpc-weird' } -MockWith {
            [pscustomobject]@{
                ManagedDeviceName   = 'CFD-WEIRD'
                CloudPcId           = 'cpc-weird'
                DaysSinceLastSignIn = 0
                SignInStatus        = 'Reconnecting'
                LastActiveTime      = (Get-Date)
                Raw                 = @{}
            }
        }
        $pc = [pscustomobject]@{
            PSTypeName       = 'WindowsCloudPC.CloudPC'
            Id               = 'cpc-weird'
            Name             = 'CFD-WEIRD'
            ProvisioningType = 'Dedicated'
        }
        ($pc | Get-CloudPCUsageBeta).UsageStatus | Should -Be 'Reconnecting'
    }
}
