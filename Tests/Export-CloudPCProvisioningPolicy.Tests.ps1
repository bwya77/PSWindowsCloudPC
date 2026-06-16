BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Export-CloudPCProvisioningPolicy' {

    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Get-CloudPCProvisioningPolicy {
            [pscustomobject]@{
                PSTypeName   = 'WindowsCloudPC.ProvisioningPolicy'
                Id           = 'pol-1'
                DisplayName  = 'Source Policy'
                Assignments  = @(
                    [pscustomobject]@{ GroupId = 'group-1'; GroupName = 'Group One'; TargetType = '#microsoft.graph.cloudPcManagementGroupAssignmentTarget' }
                )
                Raw          = [pscustomobject]@{
                    id                       = 'pol-1'
                    createdDateTime          = '2026-01-01T00:00:00Z'
                    displayName              = 'Source Policy'
                    description              = 'Source description'
                    provisioningType         = 'dedicated'
                    imageId                  = 'Microsoftwindowsdesktop_windows-ent-cpc_23h2-ent-cpc-m365'
                    imageDisplayName         = 'Windows 11 Enterprise'
                    imageType                = 'gallery'
                    cloudPcNamingTemplate    = 'CPC-%RAND:5%'
                    enableSingleSignOn       = $true
                    localAdminEnabled        = $false
                    managedBy                = 'windows365'
                    domainJoinConfigurations = @(
                        [pscustomobject]@{ domainJoinType = 'azureADJoin'; regionName = 'automatic'; geographicLocationType = 'automatic'; regionGroup = [pscustomobject]@{ displayName = 'Automatic' } }
                    )
                    windowsSetting           = [pscustomobject]@{ locale = 'en-US' }
                    assignments              = @(
                        [pscustomobject]@{
                            id     = 'pol-1_group-1'
                            target = [pscustomobject]@{
                                '@odata.type' = '#microsoft.graph.cloudPcManagementGroupAssignmentTarget'
                                groupId       = 'group-1'
                                servicePlanId = 'service-plan-1'
                                allotmentLicensesCount = 2
                                allotmentDisplayName = 'CPC-Shared-1'
                            }
                        }
                    )
                }
            }
        }
    }

    It 'exports create-safe policy body and assignments' {
        $export = Export-CloudPCProvisioningPolicy -Id 'pol-1'

        $export.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.ProvisioningPolicyExport'
        $export.SourceId | Should -Be 'pol-1'
        $export.CreateBody.displayName | Should -Be 'Source Policy'
        $export.CreateBody.imageId | Should -Be 'Microsoftwindowsdesktop_windows-ent-cpc_23h2-ent-cpc-m365'
        $export.CreateBody.imageDisplayName | Should -Be 'Windows 11 Enterprise'
        $export.CreateBody.PSObject.Properties.Name | Should -Not -Contain 'id'
        $export.CreateBody.PSObject.Properties.Name | Should -Not -Contain 'createdDateTime'
        $export.CreateBody.domainJoinConfigurations[0].PSObject.Properties.Name | Should -Not -Contain 'geographicLocationType'
        $export.CreateBody.domainJoinConfigurations[0].PSObject.Properties.Name | Should -Not -Contain 'regionGroup'
        $export.CreateBody.domainJoinConfigurations[0].PSObject.Properties.Name | Should -Not -Contain 'regionName'
        $export.Assignments | Should -HaveCount 1
        $export.Assignments[0].GroupId | Should -Be 'group-1'
        $export.Assignments[0].GroupName | Should -Be 'Group One'
        $export.Assignments[0].ServicePlanId | Should -Be 'service-plan-1'
        $export.Assignments[0].AllotmentLicensesCount | Should -Be 2
        $export.Assignments[0].AllotmentDisplayName | Should -Be 'CPC-Shared-1'
    }

    It 'writes export JSON to path' {
        $path = Join-Path $TestDrive 'policy.json'

        $result = Export-CloudPCProvisioningPolicy -Id 'pol-1' -Path $path

        Test-Path $path | Should -BeTrue
        $json = Get-Content -Path $path -Raw | ConvertFrom-Json
        $json.CreateBody.displayName | Should -Be 'Source Policy'
        $result.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.ProvisioningPolicyExportResult'
        $result.Path | Should -Be $path
    }

    It 'does not overwrite an existing file without Force' {
        $path = Join-Path $TestDrive 'policy.json'
        Set-Content -Path $path -Value '{}'

        Export-CloudPCProvisioningPolicy -Id 'pol-1' -Path $path -ErrorAction SilentlyContinue

        Get-Content -Path $path -Raw | Should -Be "{}$([Environment]::NewLine)"
    }
}
