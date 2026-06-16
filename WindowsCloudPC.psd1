@{
    RootModule           = 'WindowsCloudPC.psm1'
    ModuleVersion = '0.1.12'
    GUID                 = 'a4f3c1d2-9b2a-4e8c-9d1f-7a6b2e9c4d11'
    Author               = 'Bradley Wyatt'
    CompanyName          = 'Windows From Anywhere'
    Copyright            = '(c) Bradley Wyatt. All rights reserved.'
    Description          = 'PowerShell module for managing and querying Windows 365 Cloud PCs via Microsoft Graph.'
    PowerShellVersion    = '7.0'
    RequiredModules      = @(
        @{ ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '0.1.12' }
    )
    FunctionsToExport    = @(
        'Connect-CloudPC',
        'Export-CloudPCProvisioningPolicy',
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
        'New-CloudPCProvisioningPolicy',
        'New-CloudPCSnapshot',
        'Remove-CloudPCProvisioningPolicy',
        'Restart-CloudPC'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('Windows365','CloudPC','W365','Intune','MicrosoftGraph','AVD')
            ProjectUri   = ''
            LicenseUri   = ''
            ReleaseNotes = 'Initial scaffold: Connect-CloudPC, Get-CloudPC, Get-CloudPCUsage.'
        }
    }
}
