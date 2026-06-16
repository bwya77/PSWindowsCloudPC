BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'New-CloudPCMaintenanceWindow' {

    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Resolve-CloudPCGroup {
            [pscustomobject]@{ Id = $GroupId; DisplayName = "Name for $GroupId" }
        }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest {
            [pscustomobject]@{
                id          = 'window-1'
                displayName = 'Off-Hours Window'
            }
        }
    }

    It 'requests CloudPC.ReadWrite.All when connecting' {
        New-CloudPCMaintenanceWindow -DisplayName 'Off-Hours Window' -WeekdayStartTime '01:00' -WeekdayEndTime '05:00' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Connect-CloudPC -Times 1 -Exactly -ParameterFilter {
            $AdditionalScopes -contains 'CloudPC.ReadWrite.All'
        }
    }

    It 'creates weekday and weekend schedules with Graph millisecond time-of-day values' {
        New-CloudPCMaintenanceWindow -DisplayName 'Off-Hours Window' -WeekdayStartTime '01:00' -WeekdayEndTime '05:00' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            if ($Method -ne 'POST' -or $Uri -ne 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/maintenanceWindows') { return $false }
            $parsed = $Body | ConvertFrom-Json
            $parsed.displayName -eq 'Off-Hours Window' -and
            $parsed.description -eq '' -and
            $parsed.notificationLeadTimeInMinutes -eq 60 -and
            $parsed.schedules[0].scheduleType -eq 'weekday' -and
            $parsed.schedules[0].startTime -eq '01:00:00.000' -and
            $parsed.schedules[0].endTime -eq '05:00:00.000' -and
            $parsed.schedules[1].scheduleType -eq 'weekend' -and
            $parsed.schedules[1].startTime -eq '01:00:00.000' -and
            $parsed.schedules[1].endTime -eq '05:00:00.000'
        }
    }

    It 'sends an explicit description when provided' {
        New-CloudPCMaintenanceWindow -DisplayName 'Described Window' -Description 'Resize window' -WeekdayStartTime '01:00' -WeekdayEndTime '05:00' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            if ($Uri -ne 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/maintenanceWindows') { return $false }
            $parsed = $Body | ConvertFrom-Json
            $parsed.description -eq 'Resize window'
        }
    }

    It 'adds a weekend schedule when both weekend times are supplied' {
        New-CloudPCMaintenanceWindow -DisplayName 'Extended Window' -WeekdayStartTime '01:00' -WeekdayEndTime '05:00' -WeekendStartTime '02:00' -WeekendEndTime '06:00' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            if ($Uri -ne 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/maintenanceWindows') { return $false }
            $parsed = $Body | ConvertFrom-Json
            $parsed.schedules.Count -eq 2 -and
            $parsed.schedules[1].scheduleType -eq 'weekend' -and
            $parsed.schedules[1].startTime -eq '02:00:00.000' -and
            $parsed.schedules[1].endTime -eq '06:00:00.000'
        }
    }

    It 'accepts custom schedule objects' {
        $schedule = @{ scheduleType = 'daily'; startTime = '02:00'; endTime = '04:30' }

        New-CloudPCMaintenanceWindow -DisplayName 'Daily Window' -Schedule $schedule -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            if ($Uri -ne 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/maintenanceWindows') { return $false }
            $parsed = $Body | ConvertFrom-Json
            $parsed.schedules[0].scheduleType -eq 'daily' -and
            $parsed.schedules[0].startTime -eq '02:00:00.000'
        }
    }

    It 'assigns groups after creation when GroupId is supplied' {
        New-CloudPCMaintenanceWindow -DisplayName 'Assigned Window' -WeekdayStartTime '01:00' -WeekdayEndTime '05:00' -GroupId 'group-1','group-2' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            if ($Uri -ne 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/maintenanceWindows/window-1/assign') { return $false }
            $parsed = $Body | ConvertFrom-Json
            $parsed.assignments.Count -eq 2 -and
            $parsed.assignments[0].target.groupId -eq 'group-1' -and
            $parsed.assignments[0].target.displayName -eq 'Name for group-1' -and
            $null -eq $parsed.assignments[0].target.'@odata.type'
        }
    }

    It 'does not call Graph when the schedule is shorter than two hours' {
        New-CloudPCMaintenanceWindow -DisplayName 'Short Window' -WeekdayStartTime '01:00' -WeekdayEndTime '02:00' -Force -Confirm:$false -ErrorAction SilentlyContinue

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
    }

    It 'returns create result metadata' {
        $result = New-CloudPCMaintenanceWindow -DisplayName 'Off-Hours Window' -WeekdayStartTime '01:00' -WeekdayEndTime '05:00' -Force -Confirm:$false

        $result.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.MaintenanceWindowCreateResult'
        $result.Id | Should -Be 'window-1'
        $result.Status | Should -Be 'Created'
        $result.AssignmentStatus | Should -Be 'Skipped'
    }

    It 'does not call Graph when WhatIf is passed' {
        $result = New-CloudPCMaintenanceWindow -DisplayName 'Off-Hours Window' -WeekdayStartTime '01:00' -WeekdayEndTime '05:00' -WhatIf

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
        $result.Status | Should -Be 'WhatIf'
    }
}
