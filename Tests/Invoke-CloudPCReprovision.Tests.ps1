BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-CloudPCReprovision' {

    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { }
    }

    It 'POSTs to the v1.0 reprovision endpoint for the given Id' {
        Invoke-CloudPCReprovision -Id 'cpc-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'POST' -and $Uri -like 'https://graph.microsoft.com/v1.0/deviceManagement/virtualEndpoint/cloudPCs/cpc-1/reprovision'
        }
    }

    It 'requests CloudPC.ReadWrite.All when connecting' {
        Invoke-CloudPCReprovision -Id 'cpc-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Connect-CloudPC -Times 1 -Exactly -ParameterFilter {
            $AdditionalScopes -contains 'CloudPC.ReadWrite.All'
        }
    }

    It 'sends Content-Type application/json with an empty body by default' {
        Invoke-CloudPCReprovision -Id 'cpc-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $ContentType -eq 'application/json' -and $Body -eq '{}'
        }
    }

    It 'adds osVersion and userAccountType to the request body when provided' {
        Invoke-CloudPCReprovision -Id 'cpc-1' -OsVersion windows11 -UserAccountType administrator -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $parsed = $Body | ConvertFrom-Json
            $parsed.osVersion -eq 'windows11' -and $parsed.userAccountType -eq 'administrator'
        }
    }

    It 'accepts WindowsCloudPC.CloudPC objects from the pipeline' {
        $cpc = [pscustomobject]@{
            PSTypeName = 'WindowsCloudPC.CloudPC'
            Id         = 'cpc-from-pipeline'
            Name       = 'CPC-PIPE-01'
        }

        $cpc | Invoke-CloudPCReprovision -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*cloudPCs/cpc-from-pipeline/reprovision'
        }
    }

    It 'reprovisions every Cloud PC piped in' {
        $cpcs = @(
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-a'; Name = 'A' }
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-b'; Name = 'B' }
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-c'; Name = 'C' }
        )

        $cpcs | Invoke-CloudPCReprovision -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 3 -Exactly
    }

    It 'is silent by default on success' {
        $result = Invoke-CloudPCReprovision -Id 'cpc-1' -Force -Confirm:$false
        $result | Should -BeNullOrEmpty
    }

    It 'emits a ReprovisionResult object with -PassThru' {
        $result = Invoke-CloudPCReprovision -Id 'cpc-1' -OsVersion windows10 -UserAccountType standardUser -PassThru -Force -Confirm:$false

        $result | Should -Not -BeNullOrEmpty
        $result.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.ReprovisionResult'
        $result.CloudPcId          | Should -Be 'cpc-1'
        $result.Status             | Should -Be 'Accepted'
        $result.OsVersion          | Should -Be 'windows10'
        $result.UserAccountType    | Should -Be 'standardUser'
        $result.ErrorMessage       | Should -BeNullOrEmpty
    }

    It 'reports Failed status with -PassThru when Graph throws' {
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { throw 'Graph 500' }

        $result = Invoke-CloudPCReprovision -Id 'cpc-broken' -PassThru -Force -Confirm:$false -ErrorAction SilentlyContinue

        $result.Status       | Should -Be 'Failed'
        $result.ErrorMessage | Should -Match 'Graph 500'
    }

    It 'does not call Graph when -WhatIf is passed' {
        Invoke-CloudPCReprovision -Id 'cpc-1' -WhatIf

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
    }
}
