function Get-CloudPCOrganizationSetting {
    <#
    .SYNOPSIS
        Returns Windows 365 Cloud PC organization settings.

    .DESCRIPTION
        Calls the Microsoft Graph beta
        https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/organizationSettings
        endpoint and returns the tenant-wide Cloud PC organization settings.

        A tenant has one cloudPcOrganizationSettings object. These settings include
        default operating system version, default user account type, Microsoft
        Endpoint Manager auto-enrollment, single sign-on, and Windows settings.

    .EXAMPLE
        Get-CloudPCOrganizationSetting

    .EXAMPLE
        Get-CloudPCOrganizationSetting |
            Select-Object OsVersion,UserAccountType,SingleSignOnEnabled,WindowsLanguage
    #>
    [CmdletBinding()]
    [OutputType('WindowsCloudPC.OrganizationSetting')]
    param()

    begin {
        Connect-CloudPC | Out-Null
    }

    process {
        $uri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/organizationSettings'
        $setting = Invoke-MgGraphRequest -Method GET -Uri $uri

        [pscustomobject]@{
            PSTypeName               = 'WindowsCloudPC.OrganizationSetting'
            Id                       = $setting.id
            OsVersion                = $setting.osVersion
            UserAccountType          = $setting.userAccountType
            MEMAutoEnrollEnabled     = $setting.enableMEMAutoEnroll
            SingleSignOnEnabled      = $setting.enableSingleSignOn
            WindowsLanguage          = $setting.windowsSettings.language
            WindowsSettings          = $setting.windowsSettings
            Raw                      = $setting
        }
    }
}
