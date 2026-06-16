BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CloudPCUserSetting' {

    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-GraphPaged {
            @(
                [pscustomobject]@{
                    id                                  = 'setting-1'
                    displayName                         = 'User Reset and Restore Settings'
                    selfServiceEnabled                  = $false
                    localAdminEnabled                   = $false
                    resetEnabled                        = $true
                    lastModifiedDateTime                = '2026-06-16T02:19:31.4608557Z'
                    createdDateTime                     = '2026-06-16T02:19:31.4608557Z'
                    provisioningSourceType              = $null
                    restorePointSetting                 = [pscustomobject]@{
                        frequencyInHours  = 12
                        frequencyType     = 'twelveHours'
                        userRestoreEnabled = $true
                    }
                    crossRegionDisasterRecoverySetting  = [pscustomobject]@{
                        crossRegionDisasterRecoveryEnabled     = $false
                        maintainCrossRegionRestorePointEnabled = $true
                        disasterRecoveryType                   = 'notConfigured'
                        userInitiatedDisasterRecoveryAllowed   = $false
                        disasterRecoveryNetworkSetting         = $null
                    }
                    notificationSetting                 = [pscustomobject]@{
                        restartPromptsDisabled = $false
                    }
                    assignments                         = @(
                        [pscustomobject]@{ id = 'assignment-1' }
                    )
                }
            )
        }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest {
            [pscustomobject]@{
                id                                  = 'setting-1'
                displayName                         = 'User Reset and Restore Settings'
                selfServiceEnabled                  = $false
                localAdminEnabled                   = $false
                resetEnabled                        = $true
                lastModifiedDateTime                = '2026-06-16T02:19:31.4608557Z'
                createdDateTime                     = '2026-06-16T02:19:31.4608557Z'
                provisioningSourceType              = $null
                restorePointSetting                 = [pscustomobject]@{
                    frequencyInHours  = 12
                    frequencyType     = 'twelveHours'
                    userRestoreEnabled = $true
                }
                crossRegionDisasterRecoverySetting  = [pscustomobject]@{
                    crossRegionDisasterRecoveryEnabled     = $false
                    maintainCrossRegionRestorePointEnabled = $true
                    disasterRecoveryType                   = 'notConfigured'
                    userInitiatedDisasterRecoveryAllowed   = $false
                    disasterRecoveryNetworkSetting         = $null
                }
                notificationSetting                 = [pscustomobject]@{
                    restartPromptsDisabled = $false
                }
                assignments                         = @(
                    [pscustomobject]@{ id = 'assignment-1' }
                )
            }
        }
    }

    It 'queries the userSettings endpoint with selected user setting metadata' {
        Get-CloudPCUserSetting | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-GraphPaged -Times 1 -Exactly -ParameterFilter {
            $Uri -like 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/userSettings*' -and
            $Uri -like '*$select=*' -and
            $Uri -like '*crossRegionDisasterRecoverySetting*' -and
            $Uri -notlike '*$expand=assignments*'
        }
    }

    It 'emits WindowsCloudPC.UserSetting objects with flattened settings' {
        $settings = Get-CloudPCUserSetting

        $settings | Should -HaveCount 1
        $settings[0].PSObject.TypeNames | Should -Contain 'WindowsCloudPC.UserSetting'
        $settings[0].DisplayName | Should -Be 'User Reset and Restore Settings'
        $settings[0].ResetEnabled | Should -BeTrue
        $settings[0].RestorePointFrequencyInHours | Should -Be 12
        $settings[0].RestorePointFrequencyType | Should -Be 'twelveHours'
        $settings[0].UserRestoreEnabled | Should -BeTrue
        $settings[0].CrossRegionDisasterRecoveryEnabled | Should -BeFalse
        $settings[0].MaintainCrossRegionRestorePointEnabled | Should -BeTrue
        $settings[0].DisasterRecoveryType | Should -Be 'notConfigured'
        $settings[0].RestartPromptsDisabled | Should -BeFalse
    }

    It 'preserves nested settings and raw Graph object' {
        $setting = Get-CloudPCUserSetting | Select-Object -First 1

        $setting.RestorePointSetting.frequencyType | Should -Be 'twelveHours'
        $setting.CrossRegionDisasterRecoverySetting.disasterRecoveryType | Should -Be 'notConfigured'
        $setting.NotificationSetting.restartPromptsDisabled | Should -BeFalse
        $setting.Raw.displayName | Should -Be 'User Reset and Restore Settings'
    }

    It 'expands assignments when requested' {
        $setting = Get-CloudPCUserSetting -IncludeAssignments | Select-Object -First 1

        Should -Invoke -ModuleName WindowsCloudPC Invoke-GraphPaged -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*$expand=assignments*'
        }
        $setting.Assignments | Should -HaveCount 1
    }

    It 'gets a single user setting by ID' {
        $setting = Get-CloudPCUserSetting -Id 'setting-1'

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and
            $Uri -like 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/userSettings/setting-1*'
        }
        $setting.Id | Should -Be 'setting-1'
    }

    It 'writes an error when a single user setting lookup fails' {
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { throw 'not found' }

        $errors = @()
        $result = Get-CloudPCUserSetting -Id 'missing' -ErrorVariable errors -ErrorAction SilentlyContinue

        $result | Should -BeNullOrEmpty
        ($errors | ForEach-Object { $_.ToString() }) -join "`n" | Should -Match "Cloud PC user setting 'missing' not found"
    }
}
