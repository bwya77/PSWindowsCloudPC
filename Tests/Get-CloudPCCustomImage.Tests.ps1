BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CloudPCCustomImage' {
    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-GraphPaged {
            @(
                [pscustomobject]@{
                    id                    = 'image-1'
                    displayName           = 'Win11-Corp'
                    operatingSystem       = 'Windows 11 Enterprise'
                    osBuildNumber         = '23H2'
                    osVersionNumber       = '10.0.22631.3593'
                    version               = '1.0.0'
                    status                = 'ready'
                    expirationDate        = '2027-01-01'
                    osStatus              = 'supported'
                    sourceImageResourceId = '/subscriptions/sub/resourceGroups/rg/providers/Microsoft.Compute/images/win11'
                    lastModifiedDateTime  = '2026-06-19T18:00:00Z'
                    sizeInGB              = 64
                }
                [pscustomobject]@{
                    id                    = 'image-2'
                    displayName           = 'Win10-Legacy'
                    operatingSystem       = 'Windows 10 Enterprise'
                    osBuildNumber         = '22H2'
                    status                = 'failed'
                    sizeInGB              = 128
                }
            )
        }
    }

    It 'queries the deviceImages endpoint with selected fields' {
        Get-CloudPCCustomImage | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-GraphPaged -Times 1 -Exactly -ParameterFilter {
            $Uri -like 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/deviceImages*' -and
            $Uri -like '*$select=*' -and
            $Uri -like '*sourceImageResourceId*'
        }
    }

    It 'emits normalized custom image objects' {
        $image = Get-CloudPCCustomImage -Id 'image-1'

        $image.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.CustomImage'
        $image.DisplayName | Should -Be 'Win11-Corp'
        $image.Status | Should -Be 'ready'
        $image.SizeGB | Should -Be 64
        $image.LastModifiedDateTime | Should -BeOfType [datetime]
    }

    It 'filters by display name and status' {
        (Get-CloudPCCustomImage -DisplayName 'Win10-Legacy').Id | Should -Be 'image-2'
        (Get-CloudPCCustomImage -Status ready).Id | Should -Be 'image-1'
    }
}
