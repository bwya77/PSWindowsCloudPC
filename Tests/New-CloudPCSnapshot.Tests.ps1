BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'New-CloudPCSnapshot' {

    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { }
        Mock -ModuleName WindowsCloudPC Get-CloudPC {
            @(
                [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-a'; Name = 'CPC-A'; ManagedDeviceId = 'md-a'; AadDeviceId = 'aad-a'; AssignedUserUpn = 'user@contoso.com'; ProvisioningPolicyId = 'pol-a'; ProvisioningPolicyName = 'Policy A' }
                [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-b'; Name = 'CPC-B'; ManagedDeviceId = 'md-b'; AadDeviceId = 'aad-b'; AssignedUserUpn = 'user@contoso.com'; ProvisioningPolicyId = 'pol-b'; ProvisioningPolicyName = 'Policy B' }
            )
        }
        Mock -ModuleName WindowsCloudPC Get-CloudPCByProvisioningPolicy {
            [pscustomobject]@{
                PSTypeName           = 'WindowsCloudPC.ProvisioningPolicyCloudPCs'
                ProvisioningPolicyId = 'pol-1'
                DisplayName          = 'W365-Flex-Shared'
                CloudPCs             = @(
                    [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-1'; Name = 'CPC-001'; ManagedDeviceId = 'md-1'; AadDeviceId = 'aad-1'; AssignedUserUpn = 'one@contoso.com' }
                    [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-2'; Name = 'CPC-002'; ManagedDeviceId = 'md-2'; AadDeviceId = 'aad-2'; AssignedUserUpn = 'two@contoso.com' }
                    [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-3'; Name = 'CPC-003'; ManagedDeviceId = 'md-3'; AadDeviceId = 'aad-3'; AssignedUserUpn = 'three@contoso.com' }
                )
            }
        }
    }

    It 'POSTs to the beta createSnapshot endpoint for the given Id' {
        New-CloudPCSnapshot -Id 'cpc-1' -Force -Confirm:$false | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'POST' -and
            $Uri -eq 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/cpc-1/createSnapshot'
        }
    }

    It 'requests CloudPC.ReadWrite.All when connecting' {
        New-CloudPCSnapshot -Id 'cpc-1' -Force -Confirm:$false | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Connect-CloudPC -Times 1 -Exactly -ParameterFilter {
            $AdditionalScopes -contains 'CloudPC.ReadWrite.All'
        }
    }

    It 'sends an empty JSON body by default' {
        New-CloudPCSnapshot -Id 'cpc-1' -Force -Confirm:$false | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $ContentType -eq 'application/json' -and $Body -eq '{}'
        }
    }

    It 'adds storageAccountId and accessTier to the request body when provided' {
        New-CloudPCSnapshot -Id 'cpc-1' -StorageAccountId 'storage-1' -AccessTier cool -Force -Confirm:$false | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $parsed = $Body | ConvertFrom-Json
            $parsed.storageAccountId -eq 'storage-1' -and $parsed.accessTier -eq 'cool'
        }
    }

    It 'accepts WindowsCloudPC.CloudPC objects from the pipeline' {
        $cpc = [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-pipe'; Name = 'CPC-PIPE'; AssignedUserUpn = 'pipe@contoso.com' }

        $result = $cpc | New-CloudPCSnapshot -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*cloudPCs/cpc-pipe/createSnapshot'
        }
        $result.CloudPcName | Should -Be 'CPC-PIPE'
    }

    It 'resolves a Cloud PC friendly name' {
        $result = New-CloudPCSnapshot -CloudPC 'CPC-A' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Get-CloudPC -Times 1 -Exactly
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*cloudPCs/cpc-a/createSnapshot'
        }
        $result.CloudPcName | Should -Be 'CPC-A'
    }

    It 'creates snapshots for all Cloud PCs' {
        $result = New-CloudPCSnapshot -All -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Get-CloudPC -Times 1 -Exactly
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 2 -Exactly
        $result.CloudPcName | Should -Be @('CPC-A','CPC-B')
    }

    It 'creates snapshots for all Cloud PCs assigned to a user' {
        $result = New-CloudPCSnapshot -User 'user@contoso.com' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Get-CloudPC -Times 1 -Exactly -ParameterFilter {
            $UserPrincipalName -eq 'user@contoso.com'
        }
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 2 -Exactly
        $result.CloudPcName | Should -Be @('CPC-A','CPC-B')
    }

    It 'creates snapshots for all Cloud PCs in a provisioning policy' {
        $result = New-CloudPCSnapshot -ProvisioningPolicyId 'pol-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Get-CloudPCByProvisioningPolicy -Times 1 -Exactly -ParameterFilter {
            $ProvisioningPolicyId -eq 'pol-1'
        }
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 3 -Exactly
        $result.CloudPcName | Should -Be @('CPC-001','CPC-002','CPC-003')
        $result.ProvisioningPolicyId | Should -Be @('pol-1','pol-1','pol-1')
        $result.ProvisioningPolicyName | Should -Be @('W365-Flex-Shared','W365-Flex-Shared','W365-Flex-Shared')
    }

    It 'excludes Cloud PCs by name, id, managed device id, or assigned user UPN' {
        $result = New-CloudPCSnapshot -ProvisioningPolicyId 'pol-1' -ExcludeCloudPC 'CPC-001','cpc-2','three@contoso.com' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
        $result | Should -HaveCount 3
        $result.Status | Should -Be @('Excluded','Excluded','Excluded')
    }

    It 'emits one result row per target' {
        $result = New-CloudPCSnapshot -All -Force -Confirm:$false

        $result | Should -HaveCount 2
        $result[0].PSObject.TypeNames | Should -Contain 'WindowsCloudPC.SnapshotRequestResult'
        $result.Status | Should -Be @('Accepted','Accepted')
    }

    It 'does not call Graph when -WhatIf is passed' {
        $result = New-CloudPCSnapshot -All -WhatIf

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
        $result.Status | Should -Be @('WhatIf','WhatIf')
    }

    It 'reports Failed status when Graph throws' {
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { throw 'Graph 500' }

        $result = New-CloudPCSnapshot -Id 'cpc-broken' -Force -Confirm:$false -ErrorAction SilentlyContinue

        $result.Status | Should -Be 'Failed'
        $result.ErrorMessage | Should -Match 'Graph 500'
    }
}
