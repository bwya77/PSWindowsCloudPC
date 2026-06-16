BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-CloudPCPolicyReprovision' {

    BeforeEach {
        Mock -ModuleName WindowsCloudPC Get-CloudPCByProvisioningPolicy {
            [pscustomobject]@{
                PSTypeName              = 'WindowsCloudPC.ProvisioningPolicyCloudPCs'
                Id                      = 'pol-1'
                ProvisioningPolicyId    = 'pol-1'
                DisplayName             = 'W365-Flex-Shared'
                CloudPCCount            = 4
                CloudPCs                = @(
                    [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-1'; Name = 'CPC-001'; ManagedDeviceId = 'md-1'; AadDeviceId = 'aad-1'; AssignedUserUpn = 'one@contoso.com' }
                    [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-2'; Name = 'CPC-002'; ManagedDeviceId = 'md-2'; AadDeviceId = 'aad-2'; AssignedUserUpn = 'two@contoso.com' }
                    [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-3'; Name = 'CPC-003'; ManagedDeviceId = 'md-3'; AadDeviceId = 'aad-3'; AssignedUserUpn = 'three@contoso.com' }
                    [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-4'; Name = 'CPC-004'; ManagedDeviceId = 'md-4'; AadDeviceId = 'aad-4'; AssignedUserUpn = 'four@contoso.com' }
                )
            }
        }

        Mock -ModuleName WindowsCloudPC Invoke-CloudPCReprovision {
            [pscustomobject]@{
                PSTypeName      = 'WindowsCloudPC.ReprovisionResult'
                CloudPcId       = $CloudPC.Id
                CloudPcName     = $CloudPC.Name
                Status          = 'Accepted'
                RequestedAt     = [datetime]'2026-06-15T20:00:00'
                OsVersion       = $OsVersion
                UserAccountType = $UserAccountType
                ErrorMessage    = $null
            }
        }
    }

    It 'resolves Cloud PCs for the specified provisioning policy' {
        Invoke-CloudPCPolicyReprovision -ProvisioningPolicyId 'pol-1' -Force -Confirm:$false | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Get-CloudPCByProvisioningPolicy -Times 1 -Exactly -ParameterFilter {
            $ProvisioningPolicyId -eq 'pol-1'
        }
    }

    It 'invokes reprovision against every Cloud PC by default' {
        Invoke-CloudPCPolicyReprovision -ProvisioningPolicyId 'pol-1' -Force -Confirm:$false | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-CloudPCReprovision -Times 4 -Exactly
    }

    It 'outputs one result row per Cloud PC so the target list is visible' {
        $rows = Invoke-CloudPCPolicyReprovision -ProvisioningPolicyId 'pol-1' -Force -Confirm:$false

        $rows | Should -HaveCount 4
        $rows[0].PSObject.TypeNames | Should -Contain 'WindowsCloudPC.PolicyReprovisionResult'
        $rows.CloudPcName | Should -Be @('CPC-001','CPC-002','CPC-003','CPC-004')
        $rows.Status | Should -Be @('Accepted','Accepted','Accepted','Accepted')
    }

    It 'passes osVersion and userAccountType through to each reprovision call' {
        Invoke-CloudPCPolicyReprovision -ProvisioningPolicyId 'pol-1' -OsVersion windows11 -UserAccountType administrator -Force -Confirm:$false | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-CloudPCReprovision -Times 4 -Exactly -ParameterFilter {
            $OsVersion -eq 'windows11' -and $UserAccountType -eq 'administrator'
        }
    }

    It 'excludes Cloud PCs by name, id, managed device id, or assigned user UPN' {
        $rows = Invoke-CloudPCPolicyReprovision -ProvisioningPolicyId 'pol-1' -ExcludeCloudPC 'CPC-001','cpc-2','md-3','four@contoso.com' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-CloudPCReprovision -Times 0 -Exactly
        $rows | Should -HaveCount 4
        $rows.Status | Should -Be @('Excluded','Excluded','Excluded','Excluded')
    }

    It 'invokes only non-excluded Cloud PCs and reports excluded rows' {
        $rows = Invoke-CloudPCPolicyReprovision -ProvisioningPolicyId 'pol-1' -ExcludeCloudPC 'CPC-002','cpc-4' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-CloudPCReprovision -Times 2 -Exactly
        ($rows | Where-Object Status -eq 'Accepted').CloudPcName | Should -Be @('CPC-001','CPC-003')
        ($rows | Where-Object Status -eq 'Excluded').CloudPcName | Should -Be @('CPC-002','CPC-004')
    }

    It 'does not invoke reprovision when -WhatIf is passed' {
        $rows = Invoke-CloudPCPolicyReprovision -ProvisioningPolicyId 'pol-1' -WhatIf

        Should -Invoke -ModuleName WindowsCloudPC Invoke-CloudPCReprovision -Times 0 -Exactly
        $rows.Status | Should -Be @('WhatIf','WhatIf','WhatIf','WhatIf')
    }
}

