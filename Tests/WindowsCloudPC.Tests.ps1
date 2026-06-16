BeforeDiscovery {
    $script:PublicFunctions = @(
        'Connect-CloudPC',
        'Get-CloudPC',
        'Get-CloudPCByProvisioningPolicy',
        'Get-CloudPCLaunchDetail',
        'Get-CloudPCLicensingAllotment',
        'Get-CloudPCProvisioningPolicy',
        'Get-CloudPCRemoteActionResult',
        'Get-CloudPCSettingProfile',
        'Get-CloudPCSnapshot',
        'Get-CloudPCSupportedRegion',
        'Get-CloudPCUsage',
        'Get-CloudPCUserSetting',
        'Invoke-CloudPCPolicyReprovision',
        'Invoke-CloudPCReprovision',
        'New-CloudPCSnapshot',
        'Restart-CloudPC'
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
            $exported = (Get-Command -Module WindowsCloudPC | Sort-Object Name).Name
            $expected = $PublicFunctions | Sort-Object
            $exported | Should -Be $expected
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
