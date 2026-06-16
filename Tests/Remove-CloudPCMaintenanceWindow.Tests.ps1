BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Remove-CloudPCMaintenanceWindow' {

    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Get-CloudPCMaintenanceWindow {
            [pscustomobject]@{
                PSTypeName  = 'WindowsCloudPC.MaintenanceWindow'
                Id          = 'window-1'
                DisplayName = 'Off-Hours Window'
            }
        }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { }
    }

    It 'requests CloudPC.ReadWrite.All when connecting' {
        Remove-CloudPCMaintenanceWindow -Id 'window-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Connect-CloudPC -Times 1 -Exactly -ParameterFilter {
            $AdditionalScopes -contains 'CloudPC.ReadWrite.All'
        }
    }

    It 'clears assignments then deletes a maintenance window by ID' {
        Remove-CloudPCMaintenanceWindow -Id 'window-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            if ($Method -ne 'POST' -or $Uri -ne 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/maintenanceWindows/window-1/assign') { return $false }
            $parsed = $Body | ConvertFrom-Json
            $parsed.assignments.Count -eq 0
        }
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'DELETE' -and
            $Uri -eq 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/maintenanceWindows/window-1'
        }
    }

    It 'deletes a maintenance window by exact display name' {
        Remove-CloudPCMaintenanceWindow -DisplayName 'Off-Hours Window' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Get-CloudPCMaintenanceWindow -Times 1 -Exactly -ParameterFilter {
            $DisplayName -eq 'Off-Hours Window'
        }
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*/maintenanceWindows/window-1'
        }
    }

    It 'accepts maintenance window objects from the pipeline' {
        [pscustomobject]@{
            PSTypeName  = 'WindowsCloudPC.MaintenanceWindow'
            Id          = 'window-1'
            DisplayName = 'Off-Hours Window'
        } | Remove-CloudPCMaintenanceWindow -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'DELETE' -and $Uri -like '*/maintenanceWindows/window-1'
        }
    }

    It 'returns delete result metadata with PassThru' {
        $result = [pscustomobject]@{
            PSTypeName  = 'WindowsCloudPC.MaintenanceWindow'
            Id          = 'window-1'
            DisplayName = 'Off-Hours Window'
        } | Remove-CloudPCMaintenanceWindow -Force -Confirm:$false -PassThru

        $result.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.MaintenanceWindowRemoveResult'
        $result.Id | Should -Be 'window-1'
        $result.DisplayName | Should -Be 'Off-Hours Window'
        $result.Status | Should -Be 'Deleted'
        $result.ErrorMessage | Should -BeNullOrEmpty
    }

    It 'does not call Graph when WhatIf is passed' {
        $result = Remove-CloudPCMaintenanceWindow -Id 'window-1' -WhatIf -PassThru

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
        $result.Status | Should -Be 'WhatIf'
    }
}
