BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Update-CloudPCOrganizationSetting' {
    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { }
    }

    It 'requests CloudPC.ReadWrite.All when connecting' {
        Update-CloudPCOrganizationSetting -EnableSingleSignOn $true -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Connect-CloudPC -Times 1 -Exactly -ParameterFilter {
            $AdditionalScopes -contains 'CloudPC.ReadWrite.All'
        }
    }

    It 'PATCHes only supplied settings' {
        Update-CloudPCOrganizationSetting -OsVersion windows11 -EnableSingleSignOn $true -WindowsLanguage en-US -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'PATCH' -and
            $Uri -eq 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/organizationSettings' -and
            $ContentType -eq 'application/json' -and
            $Body -match '"osVersion"\s*:\s*"windows11"' -and
            $Body -match '"enableSingleSignOn"\s*:\s*true' -and
            $Body -match '"language"\s*:\s*"en-US"' -and
            $Body -notmatch 'userAccountType'
        }
    }

    It 'does not call Graph with WhatIf' {
        Update-CloudPCOrganizationSetting -EnableSingleSignOn $true -WhatIf

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
    }

    It 'throws when no settings are supplied' {
        { Update-CloudPCOrganizationSetting } | Should -Throw -ExpectedMessage '*specify at least one setting*'
    }

    It 'emits an update result with PassThru' {
        $result = Update-CloudPCOrganizationSetting -UserAccountType standardUser -Force -Confirm:$false -PassThru

        $result.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.OrganizationSettingUpdateResult'
        $result.Status | Should -Be 'Accepted'
        $result.Body.userAccountType | Should -Be 'standardUser'
    }
}
