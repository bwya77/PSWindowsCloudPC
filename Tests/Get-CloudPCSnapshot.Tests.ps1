BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CloudPCSnapshot' {

    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Get-CloudPC {
            @(
                [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-a'; Name = 'CPC-A' }
                [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-b'; Name = 'CPC-B' }
            )
        }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest {
            @{
                value = @(
                    [pscustomobject]@{
                        id                   = 'snapshot-older'
                        cloudPcId            = 'cpc-1'
                        status               = 'ready'
                        createdDateTime      = '2026-06-15T13:09:31.2993356Z'
                        lastRestoredDateTime = $null
                        snapshotType         = 'automatic'
                        expirationDateTime   = $null
                        healthCheckStatus    = $null
                    }
                    [pscustomobject]@{
                        id                   = 'snapshot-newer'
                        cloudPcId            = 'cpc-1'
                        status               = 'ready'
                        createdDateTime      = '2026-06-16T01:09:36.7760576Z'
                        lastRestoredDateTime = $null
                        snapshotType         = 'automatic'
                        expirationDateTime   = $null
                        healthCheckStatus    = $null
                    }
                )
            }
        } -ParameterFilter {
            $Uri -like '*retrieveSnapshots*'
        }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest {
            [pscustomobject]@{
                id                = 'cpc-1'
                managedDeviceName = 'CPC-FRIENDLY-01'
                displayName       = 'Cloud PC Friendly'
            }
        } -ParameterFilter {
            $Uri -like 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/*?$select=*' -and
            $Uri -notlike '*retrieveSnapshots*'
        }
    }

    It 'queries the retrieveSnapshots endpoint for the given Id' {
        Get-CloudPCSnapshot -Id 'cpc-1' | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and
            $Uri -like 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/cpc-1/retrieveSnapshots*' -and
            $Uri -like '*$select=*' -and
            $Uri -like '*healthCheckStatus*'
        }
    }

    It 'emits one WindowsCloudPC.Snapshot row per snapshot' {
        $rows = Get-CloudPCSnapshot -Id 'cpc-1'

        $rows | Should -HaveCount 2
        $rows[0].PSObject.TypeNames | Should -Contain 'WindowsCloudPC.Snapshot'
        $rows[0].CloudPcId | Should -Be 'cpc-1'
        $rows[0].CloudPcName | Should -Be 'cpc-1'
        $rows[0].Status | Should -Be 'ready'
        $rows[0].SnapshotType | Should -Be 'automatic'
    }

    It 'sorts newest snapshot first' {
        $rows = Get-CloudPCSnapshot -Id 'cpc-1'

        $rows[0].SnapshotId | Should -Be 'snapshot-newer'
        $rows[1].SnapshotId | Should -Be 'snapshot-older'
    }

    It 'converts Graph timestamps to local DateTime' {
        $rows = Get-CloudPCSnapshot -Id 'cpc-1'

        $rows[0].CreatedDateTime | Should -BeOfType [datetime]
    }

    It 'accepts WindowsCloudPC.CloudPC objects from the pipeline and carries Name through' {
        $cpc = [pscustomobject]@{
            PSTypeName = 'WindowsCloudPC.CloudPC'
            Id         = 'cpc-from-pipeline'
            Name       = 'CPC-PIPE-01'
        }

        $rows = $cpc | Get-CloudPCSnapshot

        $rows | Should -HaveCount 2
        $rows[0].CloudPcId | Should -Be 'cpc-1'
        $rows[0].CloudPcName | Should -Be 'CPC-PIPE-01'
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*cloudPCs/cpc-from-pipeline/retrieveSnapshots*'
        }
    }

    It 'accepts a Cloud PC friendly name and resolves it to a Cloud PC object' {
        $rows = Get-CloudPCSnapshot -CloudPC 'CPC-A'

        Should -Invoke -ModuleName WindowsCloudPC Get-CloudPC -Times 1 -Exactly
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*cloudPCs/cpc-a/retrieveSnapshots*'
        }
        $rows | Should -HaveCount 2
        $rows[0].CloudPcName | Should -Be 'CPC-A'
    }

    It 'writes a non-terminating error when a Cloud PC friendly name is not found' {
        $errors = $null
        $rows = Get-CloudPCSnapshot -CloudPC 'missing-cpc' -ErrorVariable errors -ErrorAction SilentlyContinue

        $rows | Should -BeNullOrEmpty
        $errors | Should -Not -BeNullOrEmpty
        $errors[0].ToString() | Should -Match "Cloud PC 'missing-cpc' was not found"
    }

    It 'resolves a friendly Cloud PC name when requested with Id' {
        $rows = Get-CloudPCSnapshot -Id 'cpc-1' -ResolveName

        $rows[0].CloudPcName | Should -Be 'CPC-FRIENDLY-01'
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and
            $Uri -like 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/cpc-1?$select=*'
        }
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and
            $Uri -like 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/cpc-1/retrieveSnapshots*'
        }
    }

    It 'falls back to the Cloud PC Id when name lookup fails' {
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { throw 'name lookup failed' } -ParameterFilter {
            $Uri -like 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/*?$select=*' -and
            $Uri -notlike '*retrieveSnapshots*'
        }

        $warnings = $null
        $rows = Get-CloudPCSnapshot -Id 'cpc-1' -ResolveName -WarningVariable warnings

        $rows[0].CloudPcName | Should -Be 'cpc-1'
        $warnings | Should -Not -BeNullOrEmpty
        $warnings[0].Message | Should -Match 'name lookup failed'
    }

    It 'queries each Cloud PC piped in' {
        $cpcs = @(
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-a'; Name = 'A' }
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-b'; Name = 'B' }
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-c'; Name = 'C' }
        )

        $cpcs | Get-CloudPCSnapshot | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 3 -Exactly
    }

    It 'lists snapshots for all Cloud PCs with friendly names' {
        $rows = Get-CloudPCSnapshot -All

        Should -Invoke -ModuleName WindowsCloudPC Get-CloudPC -Times 1 -Exactly
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 2 -Exactly -ParameterFilter {
            $Uri -like '*retrieveSnapshots*'
        }
        $rows | Should -HaveCount 4
        $rows.CloudPcName | Should -Contain 'CPC-A'
        $rows.CloudPcName | Should -Contain 'CPC-B'
    }

    It 'lists snapshots for Cloud PCs assigned to a user' {
        $rows = Get-CloudPCSnapshot -User 'user@contoso.com'

        Should -Invoke -ModuleName WindowsCloudPC Get-CloudPC -Times 1 -Exactly -ParameterFilter {
            $UserPrincipalName -eq 'user@contoso.com'
        }
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 2 -Exactly -ParameterFilter {
            $Uri -like '*retrieveSnapshots*'
        }
        $rows | Should -HaveCount 4
        $rows.CloudPcName | Should -Contain 'CPC-A'
        $rows.CloudPcName | Should -Contain 'CPC-B'
    }

    It 'writes useful verbose output in User mode' {
        $verbose = Get-CloudPCSnapshot -User 'user@contoso.com' -Verbose 4>&1 | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }

        $verbose.Message | Should -Contain "Retrieving Cloud PCs for user 'user@contoso.com'."
        $verbose.Message | Should -Contain "Found 2 Cloud PC(s) for user 'user@contoso.com'."
        $verbose.Message | Should -Contain "Retrieving snapshots for Cloud PC 'CPC-A' (cpc-a)."
        $verbose.Message | Should -Contain "Found 2 snapshot(s) for Cloud PC 'CPC-A' (cpc-a)."
    }

    It 'writes useful verbose output in All mode' {
        $verbose = Get-CloudPCSnapshot -All -Verbose 4>&1 | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }

        $verbose.Message | Should -Contain 'Retrieving all Cloud PCs.'
        $verbose.Message | Should -Contain 'Found 2 Cloud PC(s).'
        $verbose.Message | Should -Contain "Retrieving snapshots for Cloud PC 'CPC-A' (cpc-a)."
        $verbose.Message | Should -Contain "Found 2 snapshot(s) for Cloud PC 'CPC-A' (cpc-a)."
    }

    It 'returns nothing for a Cloud PC with no snapshots' {
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { @{ value = @() } } -ParameterFilter {
            $Uri -like '*retrieveSnapshots*'
        }

        $rows = Get-CloudPCSnapshot -Id 'cpc-fresh'
        $rows | Should -BeNullOrEmpty
    }

    It 'writes a non-terminating error when Graph throws' {
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { throw 'Graph 500' } -ParameterFilter {
            $Uri -like '*retrieveSnapshots*'
        }

        $errors = $null
        Get-CloudPCSnapshot -Id 'cpc-broken' -ErrorVariable errors -ErrorAction SilentlyContinue | Out-Null

        $errors | Should -Not -BeNullOrEmpty
        $errors[0].Exception.Message | Should -Match 'Graph 500'
    }

    It 'preserves the raw Graph snapshot on Raw' {
        $rows = Get-CloudPCSnapshot -Id 'cpc-1'

        $rows[0].Raw | Should -Not -BeNullOrEmpty
        $rows[0].Raw.id | Should -Be 'snapshot-newer'
    }
}
