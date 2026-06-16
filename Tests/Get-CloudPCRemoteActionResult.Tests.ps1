BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CloudPCRemoteActionResult' {

    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest {
            @{
                value = @(
                    @{
                        actionName          = 'Reprovision'
                        actionState         = 'done'
                        startDateTime       = '2026-05-28T17:35:37Z'
                        lastUpdatedDateTime = '2026-05-28T18:22:45Z'
                        cloudPcId           = 'cpc-1'
                        managedDeviceId     = '00000000-0000-0000-0000-000000000000'
                        statusDetails       = $null
                        statusDetail        = @{
                            code                  = $null
                            message               = $null
                            additionalInformation = @( @{ name = 'hasDownTime'; value = 'True' } )
                        }
                    },
                    @{
                        actionName          = 'Restart'
                        actionState         = 'done'
                        startDateTime       = '2026-06-15T23:26:13Z'
                        lastUpdatedDateTime = '2026-06-15T23:29:08Z'
                        cloudPcId           = 'cpc-1'
                        managedDeviceId     = '00000000-0000-0000-0000-000000000000'
                        statusDetails       = $null
                        statusDetail        = @{
                            code                  = $null
                            message               = $null
                            additionalInformation = @( @{ name = 'hasDownTime'; value = 'True' } )
                        }
                    }
                )
            }
        }
    }

    It 'queries the retrieveCloudPCRemoteActionResults endpoint for the given Id' {
        Get-CloudPCRemoteActionResult -Id 'cpc-1' | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and $Uri -like '*cloudPCs/cpc-1/retrieveCloudPCRemoteActionResults'
        }
    }

    It 'emits one WindowsCloudPC.RemoteActionResult row per action' {
        $rows = Get-CloudPCRemoteActionResult -Id 'cpc-1'

        $rows | Should -HaveCount 2
        $rows[0].PSObject.TypeNames | Should -Contain 'WindowsCloudPC.RemoteActionResult'
    }

    It 'sorts most recent action first (StartDateTime descending)' {
        $rows = Get-CloudPCRemoteActionResult -Id 'cpc-1'

        $rows[0].ActionName | Should -Be 'Restart'
        $rows[1].ActionName | Should -Be 'Reprovision'
    }

    It 'converts ISO timestamps to local DateTime' {
        $rows = Get-CloudPCRemoteActionResult -Id 'cpc-1'

        $rows[0].StartDateTime       | Should -BeOfType [datetime]
        $rows[0].LastUpdatedDateTime | Should -BeOfType [datetime]
    }

    It 'extracts HasDownTime from statusDetail.additionalInformation' {
        $rows = Get-CloudPCRemoteActionResult -Id 'cpc-1'
        $rows[0].HasDownTime | Should -BeTrue
    }

    It 'accepts WindowsCloudPC.CloudPC objects from the pipeline and carries Name through' {
        $cpc = [pscustomobject]@{
            PSTypeName = 'WindowsCloudPC.CloudPC'
            Id         = 'cpc-from-pipeline'
            Name       = 'CPC-PIPE-01'
        }

        $rows = $cpc | Get-CloudPCRemoteActionResult

        $rows | Should -HaveCount 2
        $rows[0].CloudPcId   | Should -Be 'cpc-from-pipeline'
        $rows[0].CloudPcName | Should -Be 'CPC-PIPE-01'
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*cloudPCs/cpc-from-pipeline/retrieveCloudPCRemoteActionResults'
        }
    }

    It 'queries each Cloud PC piped in' {
        $cpcs = @(
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-a'; Name = 'A' }
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-b'; Name = 'B' }
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-c'; Name = 'C' }
        )

        $cpcs | Get-CloudPCRemoteActionResult | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 3 -Exactly
    }

    It 'returns nothing for a PC with no action history' {
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { @{ value = @() } }

        $rows = Get-CloudPCRemoteActionResult -Id 'cpc-fresh'
        $rows | Should -BeNullOrEmpty
    }

    It 'writes a non-terminating error when Graph throws' {
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { throw 'Graph 500' }

        $errors = $null
        Get-CloudPCRemoteActionResult -Id 'cpc-broken' -ErrorVariable errors -ErrorAction SilentlyContinue | Out-Null

        $errors | Should -Not -BeNullOrEmpty
        $errors[0].Exception.Message | Should -Match 'Graph 500'
    }

    It 'preserves the raw Graph entry on .Raw' {
        $rows = Get-CloudPCRemoteActionResult -Id 'cpc-1'
        $rows[0].Raw | Should -Not -BeNullOrEmpty
    }
}
