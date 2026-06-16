BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Start-CloudPC' {

    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { }
    }

    It 'POSTs to the powerOn endpoint for the given Id' {
        Start-CloudPC -Id 'cpc-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'POST' -and $Uri -like '*cloudPCs/cpc-1/powerOn'
        }
    }

    It 'requests CloudPC.ReadWrite.All when connecting' {
        Start-CloudPC -Id 'cpc-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Connect-CloudPC -Times 1 -Exactly -ParameterFilter {
            $AdditionalScopes -contains 'CloudPC.ReadWrite.All'
        }
    }

    It 'accepts WindowsCloudPC.CloudPC objects from the pipeline' {
        $cpc = [pscustomobject]@{
            PSTypeName = 'WindowsCloudPC.CloudPC'
            Id         = 'cpc-from-pipeline'
            Name       = 'CPC-PIPE-01'
        }

        $cpc | Start-CloudPC -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*cloudPCs/cpc-from-pipeline/powerOn'
        }
    }

    It 'powers on every Cloud PC piped in' {
        $cpcs = @(
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-a'; Name = 'A' }
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-b'; Name = 'B' }
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-c'; Name = 'C' }
        )

        $cpcs | Start-CloudPC -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 3 -Exactly
    }

    It 'accepts an exact Cloud PC name for the CloudPC parameter' {
        Mock -ModuleName WindowsCloudPC Get-CloudPC {
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-from-name'; Name = 'CPC-BRAD-01' }
        }

        Start-CloudPC -CloudPC 'CPC-BRAD-01' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*cloudPCs/cpc-from-name/powerOn'
        }
    }

    It 'accepts an exact Cloud PC Id for the CloudPC parameter' {
        Mock -ModuleName WindowsCloudPC Get-CloudPC {
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-from-string-id'; Name = 'CPC-BRAD-01' }
        }

        Start-CloudPC -CloudPC 'cpc-from-string-id' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*cloudPCs/cpc-from-string-id/powerOn'
        }
    }

    It 'does not call Graph when a Cloud PC string cannot be resolved' {
        Mock -ModuleName WindowsCloudPC Get-CloudPC { @() }

        Start-CloudPC -CloudPC 'CPC-MISSING' -Force -Confirm:$false -ErrorAction SilentlyContinue

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
    }

    It 'is silent by default on success' {
        $result = Start-CloudPC -Id 'cpc-1' -Force -Confirm:$false
        $result | Should -BeNullOrEmpty
    }

    It 'emits a PowerOnResult object with -PassThru' {
        $result = Start-CloudPC -Id 'cpc-1' -PassThru -Force -Confirm:$false

        $result | Should -Not -BeNullOrEmpty
        $result.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.PowerOnResult'
        $result.CloudPcId           | Should -Be 'cpc-1'
        $result.Status              | Should -Be 'Accepted'
        $result.ErrorMessage        | Should -BeNullOrEmpty
    }

    It 'reports Failed status with -PassThru when Graph throws' {
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { throw 'Graph 500' }

        $result = Start-CloudPC -Id 'cpc-broken' -PassThru -Force -Confirm:$false -ErrorAction SilentlyContinue

        $result.Status       | Should -Be 'Failed'
        $result.ErrorMessage | Should -Match 'Graph 500'
    }

    It 'does not call Graph when -WhatIf is passed' {
        Start-CloudPC -Id 'cpc-1' -WhatIf

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
    }

    It 'fans out -WhatIf across a piped collection without calling Graph' {
        $cpcs = @(
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-a'; Name = 'A' }
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-b'; Name = 'B' }
        )

        $cpcs | Start-CloudPC -WhatIf

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
    }
}

