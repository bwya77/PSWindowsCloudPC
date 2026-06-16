function Get-CloudPCSettingProfile {
    <#
    .SYNOPSIS
        Returns Windows 365 Cloud PC setting profiles.

    .DESCRIPTION
        Calls the Microsoft Graph beta /deviceManagement/virtualEndpoint/settingProfiles
        endpoint and returns normalized WindowsCloudPC.SettingProfile objects.

        By default, the cmdlet lists setting profiles. Pass -Id to retrieve a
        single setting profile. Pass -IncludeDetails to expand assignments and
        settings, including object and list setting children.

    .PARAMETER Id
        Optional setting profile ID. When provided, the cmdlet retrieves only
        that setting profile.

    .PARAMETER IncludeDetails
        Expands assignments and settings. Settings expand children for
        microsoft.graph.cloudPcObjectSetting and microsoft.graph.cloudPcListSetting.

    .EXAMPLE
        Get-CloudPCSettingProfile | Format-Table DisplayName,ProfileType,TemplateId,IsAssigned

        Lists Cloud PC setting profiles.

    .EXAMPLE
        Get-CloudPCSettingProfile -Id '34fe1094-bf33-43dd-8bfc-92413dc624cc' -IncludeDetails

        Gets one Cloud PC setting profile with assignments and settings expanded.

    .EXAMPLE
        Get-CloudPCSettingProfile -IncludeDetails |
            Select-Object DisplayName,Assignments,Settings

        Lists Cloud PC setting profiles with assignments and settings expanded.
    #>
    [CmdletBinding()]
    [OutputType('WindowsCloudPC.SettingProfile')]
    param(
        [Parameter(Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('SettingProfileId','ProfileId')]
        [string]$Id,

        [switch]$IncludeDetails
    )

    begin {
        Connect-CloudPC | Out-Null
    }

    process {
        $expand = 'assignments,settings($expand=microsoft.graph.cloudPcObjectSetting/children,microsoft.graph.cloudPcListSetting/children)'
        $query = @()
        if ($IncludeDetails) {
            $query += '$expand=' + $expand
        }

        if ($Id) {
            $escapedId = [uri]::EscapeDataString($Id)
            $uri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/settingProfiles/' + $escapedId
            if ($query.Count -gt 0) {
                $uri += '?' + ($query -join '&')
            }

            try {
                $profiles = @( Invoke-MgGraphRequest -Method GET -Uri $uri )
            }
            catch {
                Write-Error "Cloud PC setting profile '$Id' not found: $($_.Exception.Message)"
                return
            }
        }
        else {
            $uri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/settingProfiles'
            if ($query.Count -gt 0) {
                $uri += '?' + ($query -join '&')
            }

            $profiles = Invoke-GraphPaged -Uri $uri
        }

        foreach ($profile in $profiles) {
            $settings = if ($IncludeDetails) { @($profile.settings) } else { $null }
            $assignments = if ($IncludeDetails) { @($profile.assignments) } else { $null }

            [pscustomobject]@{
                PSTypeName           = 'WindowsCloudPC.SettingProfile'
                Id                   = $profile.id
                DisplayName          = $profile.displayName
                ProfileType          = $profile.profileType
                TemplateId           = $profile.templateId
                Description          = $profile.description
                RoleScopeTagIds      = @($profile.roleScopeTagIds)
                IsAssigned           = $profile.isAssigned
                Priority             = $profile.priorityMetaData.priority
                LastModifiedDateTime = if ($profile.lastModifiedDateTime) { ([datetime]$profile.lastModifiedDateTime).ToLocalTime() } else { $null }
                AssignmentCount      = if ($IncludeDetails) { @($assignments).Count } else { $null }
                SettingCount         = if ($IncludeDetails) { @($settings).Count } else { $null }
                Assignments          = $assignments
                Settings             = $settings
                Raw                  = $profile
            }
        }
    }

    end { }
}

