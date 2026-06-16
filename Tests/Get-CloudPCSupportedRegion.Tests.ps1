BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CloudPCSupportedRegion' {

    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-GraphPaged {
            @(
                [pscustomobject]@{
                    id                     = 'region-eastus'
                    displayName            = 'eastus'
                    regionStatus           = 'available'
                    supportedSolution      = 'windows365'
                    regionGroup            = 'usEast'
                    geographicLocationType = 'usEast'
                }
                [pscustomobject]@{
                    id                     = 'region-westus2'
                    displayName            = 'westus2'
                    regionStatus           = 'restricted'
                    supportedSolution      = 'windows365'
                    regionGroup            = 'usWest'
                    geographicLocationType = 'usWest'
                }
                [pscustomobject]@{
                    id                     = 'region-westeurope'
                    displayName            = 'westeurope'
                    regionStatus           = 'available'
                    supportedSolution      = 'windows365'
                    regionGroup            = 'netherlands'
                    geographicLocationType = 'europe'
                }
                [pscustomobject]@{
                    id                     = 'region-other'
                    displayName            = 'otherregion'
                    regionStatus           = 'available'
                    supportedSolution      = 'other'
                    regionGroup            = 'other'
                    geographicLocationType = 'other'
                }
            )
        }
    }

    It 'queries the supportedRegions endpoint with selected region metadata' {
        Get-CloudPCSupportedRegion | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-GraphPaged -Times 1 -Exactly -ParameterFilter {
            $Uri -like 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/supportedRegions*' -and
            $Uri -like '*$select=*' -and
            $Uri -like '*geographicLocationType*'
        }
    }

    It 'emits WindowsCloudPC.SupportedRegion objects' {
        $regions = Get-CloudPCSupportedRegion

        $regions | Should -HaveCount 3
        $regions[0].PSObject.TypeNames | Should -Contain 'WindowsCloudPC.SupportedRegion'
        $regions[0].DisplayName | Should -Be 'eastus'
        $regions[0].RegionStatus | Should -Be 'available'
        $regions[0].SupportedSolution | Should -Be 'windows365'
        $regions[0].RegionGroup | Should -Be 'usEast'
        $regions[0].GeographicLocationType | Should -Be 'usEast'
    }

    It 'preserves the raw Graph region on Raw' {
        $region = Get-CloudPCSupportedRegion | Select-Object -First 1

        $region.Raw | Should -Not -BeNullOrEmpty
        $region.Raw.displayName | Should -Be 'eastus'
    }

    It 'filters by RegionStatus' {
        $regions = Get-CloudPCSupportedRegion -RegionStatus restricted

        $regions | Should -HaveCount 1
        $regions.DisplayName | Should -Be 'westus2'
    }

    It 'filters by RegionGroup' {
        $regions = Get-CloudPCSupportedRegion -RegionGroup usEast

        $regions | Should -HaveCount 1
        $regions.DisplayName | Should -Be 'eastus'
    }

    It 'filters by GeographicLocationType' {
        $regions = Get-CloudPCSupportedRegion -GeographicLocationType europe

        $regions | Should -HaveCount 1
        $regions.DisplayName | Should -Be 'westeurope'
    }

    It 'filters by SupportedSolution' {
        $regions = Get-CloudPCSupportedRegion -SupportedSolution other

        $regions | Should -HaveCount 1
        $regions.DisplayName | Should -Be 'otherregion'
    }
}
