BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CloudPCGalleryImage' {
    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-GraphPaged {
            @(
                [pscustomobject]@{
                    id               = 'gallery-24h2'
                    displayName      = 'Windows 11 Enterprise 24H2'
                    offerDisplayName = 'Windows 11 Enterprise'
                    skuDisplayName   = '24H2'
                    publisher        = 'microsoftwindowsdesktop'
                    recommendedSku   = 'light'
                    status           = 'supported'
                    sizeInGB         = 64
                    startDate        = '2024-09-30'
                    endDate          = '2027-10-11'
                    expirationDate   = '2028-04-11'
                    osVersionNumber  = '10.0.26100.0'
                }
                [pscustomobject]@{
                    id          = 'gallery-23h2'
                    displayName = 'Windows 11 Enterprise 23H2'
                    status      = 'deprecated'
                    sizeInGB    = 64
                }
            )
        }
    }

    It 'queries the galleryImages endpoint with selected fields' {
        Get-CloudPCGalleryImage | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-GraphPaged -Times 1 -Exactly -ParameterFilter {
            $Uri -like 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/galleryImages*' -and
            $Uri -like '*$select=*' -and
            $Uri -like '*recommendedSku*'
        }
    }

    It 'emits normalized gallery image objects' {
        $image = Get-CloudPCGalleryImage -Id 'gallery-24h2'

        $image.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.GalleryImage'
        $image.DisplayName | Should -Be 'Windows 11 Enterprise 24H2'
        $image.Status | Should -Be 'supported'
        $image.SizeGB | Should -Be 64
        $image.StartDate | Should -BeOfType [datetime]
    }

    It 'filters by display name and status' {
        (Get-CloudPCGalleryImage -DisplayName 'Windows 11 Enterprise 23H2').Id | Should -Be 'gallery-23h2'
        (Get-CloudPCGalleryImage -Status supported).Id | Should -Be 'gallery-24h2'
    }
}
