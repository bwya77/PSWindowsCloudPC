BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop

    function New-TestPolicyExport {
        [pscustomobject]@{
            PSTypeName    = 'WindowsCloudPC.ProvisioningPolicyExport'
            ExportVersion = 1
            SourceId      = 'source-policy-id'
            DisplayName   = 'Source Policy'
            CreateBody    = [pscustomobject]@{
                '@odata.type'            = '#microsoft.graph.cloudPcProvisioningPolicy'
                displayName              = 'Source Policy'
                description              = 'Source description'
                provisioningType         = 'dedicated'
                imageDisplayName         = 'Windows 11 Enterprise'
                imageId                  = 'Microsoftwindowsdesktop_windows-ent-cpc_23h2-ent-cpc-m365'
                imageType                = 'gallery'
                cloudPcNamingTemplate    = 'CPC-%RAND:5%'
                enableSingleSignOn       = $true
                localAdminEnabled        = $false
                managedBy                = 'windows365'
                autopilotConfiguration   = [pscustomobject]@{
                    devicePreparationProfileId = 'device-prep-profile-id'
                    applicationTimeoutInMinutes = 60
                    onFailureDeviceAccessDenied = $false
                }
                domainJoinConfigurations = @([pscustomobject]@{ domainJoinType = 'azureADJoin'; regionName = 'automatic' })
                windowsSetting           = [pscustomobject]@{ locale = 'en-US' }
            }
            Assignments   = @(
                [pscustomobject]@{
                    GroupId       = 'group-1'
                    GroupName     = 'Group One'
                    TargetType    = '#microsoft.graph.cloudPcManagementGroupAssignmentTarget'
                    ServicePlanId = 'service-plan-1'
                    AllotmentLicensesCount = 2
                    AllotmentDisplayName = 'CPC-Shared-1'
                }
            )
        }
    }
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'New-CloudPCProvisioningPolicy' {

    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies' } -MockWith {
            [pscustomobject]@{
                id          = 'new-policy-id'
                displayName = 'Copied Policy'
            }
        }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest -ParameterFilter { $Uri -like '*/provisioningPolicies/new-policy-id/assign' } -MockWith { }
    }

    It 'requests CloudPC.ReadWrite.All when connecting' {
        New-TestPolicyExport | New-CloudPCProvisioningPolicy -DisplayName 'Copied Policy' -Force -Confirm:$false | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Connect-CloudPC -Times 1 -Exactly -ParameterFilter {
            $AdditionalScopes -contains 'CloudPC.ReadWrite.All'
        }
    }

    It 'POSTs the exported create body with display name override' {
        New-TestPolicyExport | New-CloudPCProvisioningPolicy -DisplayName 'Copied Policy' -Force -Confirm:$false | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            if ($Uri -ne 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies') { return $false }
            $parsed = $Body | ConvertFrom-Json
            $parsed.displayName -eq 'Copied Policy' -and
            $parsed.imageDisplayName -eq 'Windows 11 Enterprise' -and
            $parsed.imageId -eq 'Microsoftwindowsdesktop_windows-ent-cpc_23h2-ent-cpc-m365' -and
            $null -eq $parsed.domainJoinConfigurations[0].regionName -and
            $null -eq $parsed.autopilotConfiguration -and
            $null -eq $parsed.id
        }
    }

    It 'includes Autopilot configuration only when requested' {
        New-TestPolicyExport | New-CloudPCProvisioningPolicy -DisplayName 'Copied Policy' -IncludeAutopilotConfiguration -Force -Confirm:$false | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            if ($Uri -ne 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies') { return $false }
            $parsed = $Body | ConvertFrom-Json
            $parsed.autopilotConfiguration.devicePreparationProfileId -eq 'device-prep-profile-id'
        }
    }

    It 'allows region name override for Entra joined policies' {
        New-TestPolicyExport | New-CloudPCProvisioningPolicy -DisplayName 'Copied Policy' -RegionName 'eastus' -Force -Confirm:$false | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            if ($Uri -ne 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies') { return $false }
            $parsed = $Body | ConvertFrom-Json
            $parsed.domainJoinConfigurations[0].regionName -eq 'eastus'
        }
    }

    It 'stops before Graph when a required create field is missing' {
        $export = New-TestPolicyExport
        $export.CreateBody.PSObject.Properties.Remove('imageDisplayName')

        New-CloudPCProvisioningPolicy -InputObject $export -DisplayName 'Copied Policy' -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
    }

    It 'creates assignments when Assign is specified' {
        New-TestPolicyExport | New-CloudPCProvisioningPolicy -DisplayName 'Copied Policy' -Assign -Force -Confirm:$false | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            if ($Uri -notlike '*/provisioningPolicies/new-policy-id/assign') { return $false }
            $parsed = $Body | ConvertFrom-Json
            $parsed.assignments[0].id -eq 'new-policy-id_group-1' -and
            $parsed.assignments[0].target.groupId -eq 'group-1' -and
            $parsed.assignments[0].target.'@odata.type' -eq 'microsoft.graph.cloudPcManagementGroupAssignmentTarget'
        }
    }

    It 'omits assignment ids for shared provisioning types' {
        $export = New-TestPolicyExport
        $export.CreateBody.provisioningType = 'sharedByUser'

        $export | New-CloudPCProvisioningPolicy -DisplayName 'Copied Policy' -Assign -Force -Confirm:$false | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            if ($Uri -notlike '*/provisioningPolicies/new-policy-id/assign') { return $false }
            $parsed = $Body | ConvertFrom-Json
            $null -eq $parsed.assignments[0].id -and
            $parsed.assignments[0].target.groupId -eq 'group-1' -and
            $parsed.assignments[0].target.servicePlanId -eq 'service-plan-1'
        }
    }

    It 'includes allotment count for shared by Entra group assignments' {
        $export = New-TestPolicyExport
        $export.CreateBody.provisioningType = 'sharedByEntraGroup'

        $export | New-CloudPCProvisioningPolicy -DisplayName 'Copied Policy' -Assign -Force -Confirm:$false | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            if ($Uri -notlike '*/provisioningPolicies/new-policy-id/assign') { return $false }
            $parsed = $Body | ConvertFrom-Json
            $parsed.assignments[0].target.allotmentLicensesCount -eq 2 -and
            $parsed.assignments[0].target.allotmentDisplayName -eq 'CPC-Shared-1'
        }
    }

    It 'overrides allotment count when requested' {
        $export = New-TestPolicyExport
        $export.CreateBody.provisioningType = 'sharedByEntraGroup'

        $export | New-CloudPCProvisioningPolicy -DisplayName 'Copied Policy' -AllotmentLicensesCount 1 -Assign -Force -Confirm:$false | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            if ($Uri -notlike '*/provisioningPolicies/new-policy-id/assign') { return $false }
            $parsed = $Body | ConvertFrom-Json
            $parsed.assignments[0].target.allotmentLicensesCount -eq 1
        }
    }

    It 'stops shared assignment imports when service plan id is missing' {
        $export = New-TestPolicyExport
        $export.CreateBody.provisioningType = 'sharedByUser'
        $export.Assignments[0].PSObject.Properties.Remove('ServicePlanId')

        $export | New-CloudPCProvisioningPolicy -DisplayName 'Copied Policy' -Assign -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly -ParameterFilter {
            $Uri -like '*/provisioningPolicies/new-policy-id/assign'
        }
    }

    It 'stops shared by Entra group assignment imports when allotment count is missing' {
        $export = New-TestPolicyExport
        $export.CreateBody.provisioningType = 'sharedByEntraGroup'
        $export.Assignments[0].PSObject.Properties.Remove('AllotmentLicensesCount')

        $export | New-CloudPCProvisioningPolicy -DisplayName 'Copied Policy' -Assign -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly -ParameterFilter {
            $Uri -like '*/provisioningPolicies/new-policy-id/assign'
        }
    }

    It 'returns create result metadata' {
        $result = New-TestPolicyExport | New-CloudPCProvisioningPolicy -DisplayName 'Copied Policy' -Assign -Force -Confirm:$false

        $result.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.ProvisioningPolicyCreateResult'
        $result.Id | Should -Be 'new-policy-id'
        $result.Status | Should -Be 'Created'
        $result.AssignmentStatus | Should -Be 'Assigned'
        $result.AssignmentsApplied | Should -Be 1
    }

    It 'does not call Graph when WhatIf is passed' {
        $result = New-TestPolicyExport | New-CloudPCProvisioningPolicy -DisplayName 'Copied Policy' -Assign -WhatIf

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
        $result.Status | Should -Be 'WhatIf'
        $result.AssignmentStatus | Should -Be 'WhatIf'
    }

    It 'loads exports from a JSON file' {
        $path = Join-Path $TestDrive 'policy.json'
        New-TestPolicyExport | ConvertTo-Json -Depth 50 | Set-Content -Path $path -Encoding utf8NoBOM

        New-CloudPCProvisioningPolicy -Path $path -DisplayName 'Copied Policy' -Force -Confirm:$false | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies'
        }
    }
}
