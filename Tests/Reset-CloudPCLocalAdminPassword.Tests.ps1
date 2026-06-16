BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Reset-CloudPCLocalAdminPassword' {

    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { }
        Mock -ModuleName WindowsCloudPC Get-CloudPC {
            [pscustomobject]@{
                PSTypeName      = 'WindowsCloudPC.CloudPC'
                Id              = 'cpc-1'
                Name            = 'CPC-BRAD-01'
                ManagedDeviceId = 'md-1'
            }
        }
    }

    It 'POSTs to the rotateLocalAdminPassword endpoint for the given managed device Id' {
        Reset-CloudPCLocalAdminPassword -ManagedDeviceId 'md-direct' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'POST' -and $Uri -like "*managedDevices('md-direct')/rotateLocalAdminPassword"
        }
    }

    It 'requests DeviceManagementManagedDevices.PrivilegedOperations.All when connecting' {
        Reset-CloudPCLocalAdminPassword -ManagedDeviceId 'md-direct' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Connect-CloudPC -Times 1 -Exactly -ParameterFilter {
            $AdditionalScopes -contains 'DeviceManagementManagedDevices.PrivilegedOperations.All'
        }
    }

    It 'resolves Cloud PC Id to a managed device Id' {
        Reset-CloudPCLocalAdminPassword -Id 'cpc-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like "*managedDevices('md-1')/rotateLocalAdminPassword"
        }
    }

    It 'accepts WindowsCloudPC.CloudPC objects from the pipeline' {
        $cpc = [pscustomobject]@{
            PSTypeName      = 'WindowsCloudPC.CloudPC'
            Id              = 'cpc-from-pipeline'
            Name            = 'CPC-PIPE-01'
            ManagedDeviceId = 'md-pipeline'
        }

        $cpc | Reset-CloudPCLocalAdminPassword -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like "*managedDevices('md-pipeline')/rotateLocalAdminPassword"
        }
    }

    It 'rotates every Cloud PC piped in' {
        $cpcs = @(
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-a'; Name = 'A'; ManagedDeviceId = 'md-a' }
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-b'; Name = 'B'; ManagedDeviceId = 'md-b' }
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-c'; Name = 'C'; ManagedDeviceId = 'md-c' }
        )

        $cpcs | Reset-CloudPCLocalAdminPassword -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 3 -Exactly
    }

    It 'accepts an exact Cloud PC name for the CloudPC parameter' {
        Reset-CloudPCLocalAdminPassword -CloudPC 'CPC-BRAD-01' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like "*managedDevices('md-1')/rotateLocalAdminPassword"
        }
    }

    It 'accepts an exact managed device Id for the CloudPC parameter' {
        Reset-CloudPCLocalAdminPassword -CloudPC 'md-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like "*managedDevices('md-1')/rotateLocalAdminPassword"
        }
    }

    It 'does not call Graph when a Cloud PC string cannot be resolved' {
        Mock -ModuleName WindowsCloudPC Get-CloudPC { @() }

        Reset-CloudPCLocalAdminPassword -CloudPC 'CPC-MISSING' -Force -Confirm:$false -ErrorAction SilentlyContinue

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
    }

    It 'does not call Graph when the resolved Cloud PC has no managed device Id' {
        Mock -ModuleName WindowsCloudPC Get-CloudPC {
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-no-mdm'; Name = 'CPC-NO-MDM'; ManagedDeviceId = $null }
        }

        Reset-CloudPCLocalAdminPassword -CloudPC 'CPC-NO-MDM' -Force -Confirm:$false -ErrorAction SilentlyContinue

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
    }

    It 'is silent by default on success' {
        $result = Reset-CloudPCLocalAdminPassword -ManagedDeviceId 'md-direct' -Force -Confirm:$false
        $result | Should -BeNullOrEmpty
    }

    It 'emits a LocalAdminPasswordRotationResult object with -PassThru' {
        $result = Reset-CloudPCLocalAdminPassword -ManagedDeviceId 'md-direct' -PassThru -Force -Confirm:$false

        $result | Should -Not -BeNullOrEmpty
        $result.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.LocalAdminPasswordRotationResult'
        $result.ManagedDeviceId    | Should -Be 'md-direct'
        $result.Status             | Should -Be 'Accepted'
        $result.ErrorMessage       | Should -BeNullOrEmpty
    }

    It 'reports Failed status with -PassThru when Graph throws' {
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { throw 'Graph 500' }

        $result = Reset-CloudPCLocalAdminPassword -ManagedDeviceId 'md-broken' -PassThru -Force -Confirm:$false -ErrorAction SilentlyContinue

        $result.Status       | Should -Be 'Failed'
        $result.ErrorMessage | Should -Match 'Graph 500'
    }

    It 'does not call Graph when -WhatIf is passed' {
        Reset-CloudPCLocalAdminPassword -ManagedDeviceId 'md-direct' -WhatIf

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
    }
}

