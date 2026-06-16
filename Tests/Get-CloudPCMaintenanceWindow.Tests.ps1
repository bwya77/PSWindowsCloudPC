BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}
AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CloudPCMaintenanceWindow' {

    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Resolve-CloudPCGroup -ParameterFilter { $GroupId -eq 'group-1' } -MockWith {
            [pscustomobject]@{ Id = 'group-1'; DisplayName = 'Windows 365 Users' }
        }
        Mock -ModuleName WindowsCloudPC Invoke-GraphPaged {
            @(
                [pscustomobject]@{
                    id                            = 'window-1'
                    displayName                   = 'Off-Hours Window'
                    description                   = 'Resize window'
                    notificationLeadTimeInMinutes = 60
                    schedules                     = @(
                        [pscustomobject]@{ scheduleType = 'weekday'; startTime = '01:00:00.0000000'; endTime = '05:00:00.0000000' }
                    )
                    assignments                   = @(
                        [pscustomobject]@{ target = [pscustomobject]@{ '@odata.type' = 'microsoft.graph.cloudPcManagementGroupAssignmentTarget'; groupId = 'group-1' } }
                    )
                }
            )
        }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest {
            [pscustomobject]@{
                id                            = 'window-1'
                displayName                   = 'Off-Hours Window'
                description                   = 'Resize window'
                notificationLeadTimeInMinutes = 60
                schedules                     = @(
                    [pscustomobject]@{ scheduleType = 'weekday'; startTime = '01:00:00.0000000'; endTime = '05:00:00.0000000' }
                )
            }
        }
    }

    It 'returns normalized maintenance window objects' {
        $result = Get-CloudPCMaintenanceWindow

        $result.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.MaintenanceWindow'
        $result.MaintenanceWindowId | Should -Be 'window-1'
        $result.ScheduleSummary | Should -Be 'weekday 01:00:00.0000000-05:00:00.0000000'
        $result.Raw | Should -Not -BeNullOrEmpty
    }

    It 'filters by exact display name locally' {
        $result = Get-CloudPCMaintenanceWindow -DisplayName 'Off-Hours Window'

        $result | Should -HaveCount 1
        Should -Invoke -ModuleName WindowsCloudPC Invoke-GraphPaged -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/maintenanceWindows'
        }
    }

    It 'expands and resolves group assignments when requested' {
        $result = Get-CloudPCMaintenanceWindow -IncludeAssignments

        $result.AssignedGroupIds | Should -Contain 'group-1'
        $result.AssignedGroupNames | Should -Contain 'Windows 365 Users'
        Should -Invoke -ModuleName WindowsCloudPC Invoke-GraphPaged -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/maintenanceWindows?$expand=assignments'
        }
    }

    It 'gets one maintenance window by ID' {
        $result = Get-CloudPCMaintenanceWindow -Id 'window-1'

        $result.Id | Should -Be 'window-1'
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and
            $Uri -eq 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/maintenanceWindows/window-1'
        }
    }
}
