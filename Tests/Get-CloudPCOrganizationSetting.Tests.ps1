BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CloudPCOrganizationSetting' {
    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest {
            [pscustomobject]@{
                id                  = 'org-setting-1'
                osVersion           = 'windows11'
                userAccountType     = 'standardUser'
                enableMEMAutoEnroll = $true
                enableSingleSignOn  = $true
                windowsSettings     = [pscustomobject]@{
                    language = 'en-US'
                }
            }
        }
    }

    It 'queries the organizationSettings endpoint' {
        Get-CloudPCOrganizationSetting | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and
            $Uri -eq 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/organizationSettings'
        }
    }

    It 'returns a normalized WindowsCloudPC.OrganizationSetting object' {
        $setting = Get-CloudPCOrganizationSetting

        $setting.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.OrganizationSetting'
        $setting.Id | Should -Be 'org-setting-1'
        $setting.OsVersion | Should -Be 'windows11'
        $setting.UserAccountType | Should -Be 'standardUser'
        $setting.MEMAutoEnrollEnabled | Should -BeTrue
        $setting.SingleSignOnEnabled | Should -BeTrue
        $setting.WindowsLanguage | Should -Be 'en-US'
    }

    It 'preserves WindowsSettings and Raw payload' {
        $setting = Get-CloudPCOrganizationSetting

        $setting.WindowsSettings.language | Should -Be 'en-US'
        $setting.Raw | Should -Not -BeNullOrEmpty
        $setting.Raw.enableSingleSignOn | Should -BeTrue
    }
}
