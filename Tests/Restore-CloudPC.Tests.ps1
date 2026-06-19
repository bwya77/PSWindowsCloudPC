BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Restore-CloudPC' {
    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { }
        Mock -ModuleName WindowsCloudPC Get-CloudPC {
            [pscustomobject]@{
                PSTypeName = 'WindowsCloudPC.CloudPC'
                Id         = 'cpc-1'
                Name       = 'CPC-USER-01'
                Raw        = @{ displayName = 'Cloud PC User 01'; managedDeviceName = 'CPC-USER-01' }
            }
        }
    }

    It 'requests CloudPC.ReadWrite.All when connecting' {
        Restore-CloudPC -Id 'cpc-1' -SnapshotId 'snapshot-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Connect-CloudPC -Times 1 -Exactly -ParameterFilter {
            $AdditionalScopes -contains 'CloudPC.ReadWrite.All'
        }
    }

    It 'POSTs to the v1.0 restore endpoint with cloudPcSnapshotId body' {
        Restore-CloudPC -Id 'cpc-1' -SnapshotId 'snapshot-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'POST' -and
            $Uri -eq 'https://graph.microsoft.com/v1.0/deviceManagement/virtualEndpoint/cloudPCs/cpc-1/restore' -and
            $ContentType -eq 'application/json' -and
            $Body -match '"cloudPcSnapshotId"\s*:\s*"snapshot-1"'
        }
    }

    It 'accepts Cloud PC objects from the pipeline' {
        $pc = [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-pipe'; Name = 'CPC-PIPE-01' }

        $pc | Restore-CloudPC -SnapshotId 'snapshot-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*cloudPCs/cpc-pipe/restore'
        }
    }

    It 'accepts WindowsCloudPC.Snapshot pipeline input' {
        $snapshot = [pscustomobject]@{
            PSTypeName   = 'WindowsCloudPC.Snapshot'
            CloudPcId    = 'cpc-from-snapshot'
            CloudPcName  = 'CPC-SNAPSHOT-01'
            SnapshotId   = 'snapshot-from-object'
        }

        $snapshot | Restore-CloudPC -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*cloudPCs/cpc-from-snapshot/restore' -and
            $Body -match '"cloudPcSnapshotId"\s*:\s*"snapshot-from-object"'
        }
    }

    It 'does not call Graph when -WhatIf is passed' {
        Restore-CloudPC -Id 'cpc-1' -SnapshotId 'snapshot-1' -WhatIf

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
    }

    It 'emits a RestoreResult object with -PassThru' {
        $result = Restore-CloudPC -Id 'cpc-1' -SnapshotId 'snapshot-1' -Force -Confirm:$false -PassThru

        $result.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.RestoreResult'
        $result.CloudPcId | Should -Be 'cpc-1'
        $result.SnapshotId | Should -Be 'snapshot-1'
        $result.Status | Should -Be 'Accepted'
    }

    It 'reports Failed status with -PassThru when Graph throws' {
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { throw 'Graph 500' }

        $result = Restore-CloudPC -Id 'cpc-broken' -SnapshotId 'snapshot-1' -Force -Confirm:$false -PassThru -ErrorAction SilentlyContinue

        $result.Status | Should -Be 'Failed'
        $result.ErrorMessage | Should -Match 'Graph 500'
    }

    It 'requires snapshot input objects to include CloudPcId and SnapshotId' {
        $snapshot = [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.Snapshot'; SnapshotId = 'snapshot-1' }
        $errors = $null

        $snapshot | Restore-CloudPC -Force -Confirm:$false -ErrorVariable errors -ErrorAction SilentlyContinue

        $errors | Should -Not -BeNullOrEmpty
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
    }
}
