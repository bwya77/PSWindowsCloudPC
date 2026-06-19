BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Rename-CloudPC' {
    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { }
        Mock -ModuleName WindowsCloudPC Get-CloudPC {
            [pscustomobject]@{
                PSTypeName      = 'WindowsCloudPC.CloudPC'
                Id              = 'cpc-1'
                Name            = 'CPC-USER-01'
                ManagedDeviceId = 'mdm-1'
                AadDeviceId     = 'aad-1'
                AssignedUserUpn = 'user@contoso.com'
                Raw             = @{ displayName = 'Cloud PC User 01'; managedDeviceName = 'CPC-USER-01' }
            }
        }
    }

    It 'requests CloudPC.ReadWrite.All when connecting' {
        Rename-CloudPC -Id 'cpc-1' -NewDisplayName 'Cloud PC HR' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Connect-CloudPC -Times 1 -Exactly -ParameterFilter {
            $AdditionalScopes -contains 'CloudPC.ReadWrite.All'
        }
    }

    It 'POSTs to the v1.0 rename endpoint with displayName body' {
        Rename-CloudPC -Id 'cpc-1' -NewDisplayName 'Cloud PC HR' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'POST' -and
            $Uri -eq 'https://graph.microsoft.com/v1.0/deviceManagement/virtualEndpoint/cloudPCs/cpc-1/rename' -and
            $ContentType -eq 'application/json' -and
            $Body -match '"displayName"\s*:\s*"Cloud PC HR"'
        }
    }

    It 'requests privileged managed device scope when ManagedDeviceName is supplied' {
        Rename-CloudPC -CloudPC 'CPC-USER-01' -NewDisplayName 'Cloud PC HR' -ManagedDeviceName 'MDM-HR-01' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Connect-CloudPC -Times 1 -Exactly -ParameterFilter {
            $AdditionalScopes -contains 'CloudPC.ReadWrite.All' -and
            $AdditionalScopes -contains 'DeviceManagementManagedDevices.PrivilegedOperations.All'
        }
    }

    It 'POSTs to managedDevice setDeviceName when ManagedDeviceName is supplied' {
        Rename-CloudPC -CloudPC 'CPC-USER-01' -NewDisplayName 'Cloud PC HR' -ManagedDeviceName 'MDM-HR-01' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'POST' -and
            $Uri -eq 'https://graph.microsoft.com/v1.0/deviceManagement/virtualEndpoint/cloudPCs/cpc-1/rename' -and
            $Body -match '"displayName"\s*:\s*"Cloud PC HR"'
        }
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'POST' -and
            $Uri -eq 'https://graph.microsoft.com/beta/deviceManagement/managedDevices/mdm-1/setDeviceName' -and
            $Body -match '"deviceName"\s*:\s*"MDM-HR-01"'
        }
    }

    It 'accepts Cloud PC objects from the pipeline' {
        $pc = [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-pipe'; Name = 'CPC-PIPE-01' }

        $pc | Rename-CloudPC -NewDisplayName 'Cloud PC Pipeline' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*cloudPCs/cpc-pipe/rename'
        }
    }

    It 'resolves exact Cloud PC names' {
        Rename-CloudPC -CloudPC 'CPC-USER-01' -NewDisplayName 'Cloud PC HR' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Get-CloudPC -Times 1 -Exactly
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*cloudPCs/cpc-1/rename'
        }
    }

    It 'does not call Graph when -WhatIf is passed' {
        Rename-CloudPC -Id 'cpc-1' -NewDisplayName 'Cloud PC HR' -WhatIf

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
    }

    It 'does not call either rename endpoint when -WhatIf is passed with ManagedDeviceName' {
        Rename-CloudPC -CloudPC 'CPC-USER-01' -NewDisplayName 'Cloud PC HR' -ManagedDeviceName 'MDM-HR-01' -WhatIf

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
    }

    It 'emits a RenameResult object with -PassThru' {
        $result = Rename-CloudPC -Id 'cpc-1' -NewDisplayName 'Cloud PC HR' -Force -Confirm:$false -PassThru

        $result.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.RenameResult'
        $result.CloudPcId | Should -Be 'cpc-1'
        $result.NewDisplayName | Should -Be 'Cloud PC HR'
        $result.Status | Should -Be 'Accepted'
        $result.ManagedDeviceRenameStatus | Should -Be 'NotRequested'
    }

    It 'emits managed device rename status with -PassThru' {
        $result = Rename-CloudPC -CloudPC 'CPC-USER-01' -NewDisplayName 'Cloud PC HR' -ManagedDeviceName 'MDM-HR-01' -Force -Confirm:$false -PassThru

        $result.ManagedDeviceId | Should -Be 'mdm-1'
        $result.NewManagedDeviceName | Should -Be 'MDM-HR-01'
        $result.ManagedDeviceRenameStatus | Should -Be 'Accepted'
    }

    It 'reports Failed status with -PassThru when Graph throws' {
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { throw 'Graph 500' }

        $result = Rename-CloudPC -Id 'cpc-broken' -NewDisplayName 'Cloud PC HR' -Force -Confirm:$false -PassThru -ErrorAction SilentlyContinue

        $result.Status | Should -Be 'Failed'
        $result.ErrorMessage | Should -Match 'Graph 500'
    }
}
