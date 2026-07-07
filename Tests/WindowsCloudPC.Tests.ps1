BeforeDiscovery {
    $script:PublicFunctions = @(
        'Connect-CloudPC',
        'Export-CloudPCProvisioningPolicy',
        'Get-CloudPC',
        'Get-CloudPCByProvisioningPolicy',
        'Get-CloudPCConnectivityHistory',
        'Get-CloudPCCustomImage',
        'Get-CloudPCDiskSpace',
        'Get-CloudPCGalleryImage',
        'Get-CloudPCLaunchDetail',
        'Get-CloudPCLicensingAllotment',
        'Get-CloudPCMaintenanceWindow',
        'Get-CloudPCOrganizationSetting',
        'Get-CloudPCProvisioningPolicy',
        'Get-CloudPCReport',
        'Get-CloudPCRemoteActionResult',
        'Get-CloudPCServicePlan',
        'Get-CloudPCSettingProfile',
        'Get-CloudPCSnapshot',
        'Get-CloudPCSupportedRegion',
        'Get-CloudPCUsage',
        'Get-CloudPCUserSetting',
        'Invoke-CloudPCEndGracePeriod',
        'Invoke-CloudPCPolicyReprovision',
        'Invoke-CloudPCReprovision',
        'New-CloudPCMaintenanceWindow',
        'New-CloudPCProvisioningPolicy',
        'New-CloudPCSnapshot',
        'Remove-CloudPCMaintenanceWindow',
        'Remove-CloudPCProvisioningPolicy',
        'Rename-CloudPC',
        'Reset-CloudPCLocalAdminPassword',
        'Resize-CloudPC',
        'Restore-CloudPC',
        'Restart-CloudPC',
        'Start-CloudPC',
        'Sync-CloudPC',
        'Update-CloudPCOrganizationSetting'
    )

    $script:PublicAliases = @(
        'Connect-Windows365'
    )
}

Describe 'WindowsCloudPC module' {

    BeforeAll {
        $script:ModuleRoot   = Split-Path $PSScriptRoot -Parent
        $script:ManifestPath = Join-Path $ModuleRoot 'WindowsCloudPC.psd1'
        Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module $ManifestPath -Force -ErrorAction Stop
        $script:Manifest = Test-ModuleManifest -Path $ManifestPath
    }

    AfterAll {
        Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    }

    Context 'Manifest' {
        It 'has a valid manifest' {
            $Manifest | Should -Not -BeNullOrEmpty
        }

        It 'targets PowerShell 7+' {
            $Manifest.PowerShellVersion | Should -BeGreaterOrEqual ([version]'7.0')
        }

        It 'requires Microsoft.Graph.Authentication' {
            $Manifest.RequiredModules.Name | Should -Contain 'Microsoft.Graph.Authentication'
        }

        It 'has a non-empty GUID' {
            $Manifest.Guid | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Exports' {
        It 'exports exactly the expected public functions' {
            $exported = (Get-Command -Module WindowsCloudPC -CommandType Function | Sort-Object Name).Name
            $expected = $PublicFunctions | Sort-Object
            $exported | Should -Be $expected
        }

        It 'exports exactly the expected aliases' {
            $exported = (Get-Command -Module WindowsCloudPC -CommandType Alias | Sort-Object Name).Name
            $expected = $PublicAliases | Sort-Object
            $exported | Should -Be $expected
        }

        It 'maps Connect-Windows365 to Connect-CloudPC' {
            $alias = Get-Alias -Name Connect-Windows365 -ErrorAction Stop
            $alias.Definition | Should -Be 'Connect-CloudPC'
        }
    }

    Context 'Help' {
        It 'has a non-empty synopsis for <_>' -ForEach $PublicFunctions {
            $help = Get-Help $_ -ErrorAction Stop
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $help.Synopsis | Should -Not -Match '^\s*\w[\w-]+\s*\['
        }

        It 'has at least one example for <_>' -ForEach $PublicFunctions {
            $help = Get-Help $_ -Examples -ErrorAction Stop
            $help.Examples.Example | Should -Not -BeNullOrEmpty
        }
    }
}
