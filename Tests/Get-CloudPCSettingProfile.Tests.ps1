BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CloudPCSettingProfile' {

    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-GraphPaged {
            @(
                [pscustomobject]@{
                    id                   = 'profile-1'
                    displayName          = 'Windows App Allow Management'
                    profileType          = 'template'
                    templateId           = 'W365.WindowsApp'
                    description          = ''
                    roleScopeTagIds      = @('0')
                    lastModifiedDateTime = '2026-06-16T02:20:24Z'
                    isAssigned           = $true
                    priorityMetaData     = [pscustomobject]@{
                        priority = 1
                    }
                    assignments          = @(
                        [pscustomobject]@{
                            id         = 'assignment-1'
                            profileId  = 'profile-1'
                            groupId    = 'group-1'
                            assignType = 'group'
                        }
                    )
                    settings             = @(
                        [pscustomobject]@{
                            '@odata.type'        = '#microsoft.graph.cloudPcBooleanSetting'
                            id                   = 'setting-1'
                            settingDefinitionId  = 'W365.WindowsApp.Customization.EnableReset'
                            dataType             = 'boolean'
                            platform             = 'all'
                            profileId            = 'profile-1'
                            isEnabled            = $true
                        }
                        [pscustomobject]@{
                            '@odata.type'        = '#microsoft.graph.cloudPcBooleanSetting'
                            id                   = 'setting-2'
                            settingDefinitionId  = 'W365.WindowsApp.Customization.EnableRestore'
                            dataType             = 'boolean'
                            platform             = 'all'
                            profileId            = 'profile-1'
                            isEnabled            = $true
                        }
                    )
                }
            )
        }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest {
            [pscustomobject]@{
                id                   = 'profile-1'
                displayName          = 'Windows App Allow Management'
                profileType          = 'template'
                templateId           = 'W365.WindowsApp'
                description          = ''
                roleScopeTagIds      = @('0')
                lastModifiedDateTime = '2026-06-16T02:20:24Z'
                isAssigned           = $true
                priorityMetaData     = [pscustomobject]@{
                    priority = 1
                }
                assignments          = @(
                    [pscustomobject]@{
                        id         = 'assignment-1'
                        profileId  = 'profile-1'
                        groupId    = 'group-1'
                        assignType = 'group'
                    }
                    [pscustomobject]@{
                        id         = 'assignment-2'
                        profileId  = 'profile-1'
                        groupId    = 'group-2'
                        assignType = 'group'
                    }
                )
                settings             = @(
                    [pscustomobject]@{
                        '@odata.type'        = '#microsoft.graph.cloudPcBooleanSetting'
                        id                   = 'setting-1'
                        settingDefinitionId  = 'W365.WindowsApp.Customization.EnableReset'
                        dataType             = 'boolean'
                        platform             = 'all'
                        profileId            = 'profile-1'
                        isEnabled            = $true
                    }
                    [pscustomobject]@{
                        '@odata.type'        = '#microsoft.graph.cloudPcBooleanSetting'
                        id                   = 'setting-2'
                        settingDefinitionId  = 'W365.WindowsApp.Customization.EnableRestore'
                        dataType             = 'boolean'
                        platform             = 'all'
                        profileId            = 'profile-1'
                        isEnabled            = $true
                    }
                    [pscustomobject]@{
                        '@odata.type'        = '#microsoft.graph.cloudPcBooleanSetting'
                        id                   = 'setting-3'
                        settingDefinitionId  = 'W365.WindowsApp.Customization.EnableSelfProvisioning'
                        dataType             = 'boolean'
                        platform             = 'all'
                        profileId            = 'profile-1'
                        isEnabled            = $true
                    }
                )
            }
        }
    }

    It 'lists setting profiles from the settingProfiles endpoint' {
        Get-CloudPCSettingProfile | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-GraphPaged -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/settingProfiles'
        }
    }

    It 'emits WindowsCloudPC.SettingProfile objects' {
        $profiles = Get-CloudPCSettingProfile

        $profiles | Should -HaveCount 1
        $profiles[0].PSObject.TypeNames | Should -Contain 'WindowsCloudPC.SettingProfile'
        $profiles[0].DisplayName | Should -Be 'Windows App Allow Management'
        $profiles[0].ProfileType | Should -Be 'template'
        $profiles[0].TemplateId | Should -Be 'W365.WindowsApp'
        $profiles[0].IsAssigned | Should -BeTrue
        $profiles[0].Priority | Should -Be 1
        $profiles[0].RoleScopeTagIds | Should -Contain '0'
        $profiles[0].Assignments | Should -BeNullOrEmpty
        $profiles[0].Settings | Should -BeNullOrEmpty
    }

    It 'expands assignments and settings when requested' {
        $profile = Get-CloudPCSettingProfile -IncludeDetails | Select-Object -First 1

        Should -Invoke -ModuleName WindowsCloudPC Invoke-GraphPaged -Times 1 -Exactly -ParameterFilter {
            $Uri -like 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/settingProfiles*' -and
            $Uri -like '*$expand=assignments,settings(*' -and
            $Uri -like '*microsoft.graph.cloudPcObjectSetting/children*' -and
            $Uri -like '*microsoft.graph.cloudPcListSetting/children*'
        }
        $profile.AssignmentCount | Should -Be 1
        $profile.SettingCount | Should -Be 2
        $profile.Assignments[0].groupId | Should -Be 'group-1'
        $profile.Settings[0].settingDefinitionId | Should -Be 'W365.WindowsApp.Customization.EnableReset'
    }

    It 'gets a single setting profile by ID with details' {
        $profile = Get-CloudPCSettingProfile -Id 'profile-1' -IncludeDetails

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and
            $Uri -like 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/settingProfiles/profile-1*' -and
            $Uri -like '*$expand=assignments,settings(*'
        }
        $profile.Id | Should -Be 'profile-1'
        $profile.AssignmentCount | Should -Be 2
        $profile.SettingCount | Should -Be 3
    }

    It 'preserves the raw Graph profile' {
        $profile = Get-CloudPCSettingProfile | Select-Object -First 1

        $profile.Raw.displayName | Should -Be 'Windows App Allow Management'
        $profile.Raw.priorityMetaData.priority | Should -Be 1
    }

    It 'writes an error when a single setting profile lookup fails' {
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { throw 'not found' }

        $errors = @()
        $result = Get-CloudPCSettingProfile -Id 'missing' -ErrorVariable errors -ErrorAction SilentlyContinue

        $result | Should -BeNullOrEmpty
        ($errors | ForEach-Object { $_.ToString() }) -join "`n" | Should -Match "Cloud PC setting profile 'missing' not found"
    }
}

