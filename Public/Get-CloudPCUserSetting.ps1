function Get-CloudPCUserSetting {
    <#
    .SYNOPSIS
        Returns Windows 365 Cloud PC user settings.

    .DESCRIPTION
        Calls the Microsoft Graph beta /deviceManagement/virtualEndpoint/userSettings
        endpoint and returns normalized WindowsCloudPC.UserSetting objects.

        By default, the cmdlet lists every user setting. Pass -Id to retrieve a
        single user setting. Pass -IncludeAssignments to expand group assignments.

    .PARAMETER Id
        Optional user setting ID. When provided, the cmdlet retrieves only that
        user setting.

    .PARAMETER IncludeAssignments
        Includes assignment relationships by adding $expand=assignments.

    .EXAMPLE
        Get-CloudPCUserSetting | Format-Table DisplayName,ResetEnabled,UserRestoreEnabled

        Lists Cloud PC user settings with reset and restore status.

    .EXAMPLE
        Get-CloudPCUserSetting -Id '26494f36-064f-42e8-befd-fde474840402'

        Gets one Cloud PC user setting by ID.

    .EXAMPLE
        Get-CloudPCUserSetting -IncludeAssignments |
            Select-Object DisplayName,Assignments

        Lists Cloud PC user settings and expands assignment relationships.
    #>
    [CmdletBinding()]
    [OutputType('WindowsCloudPC.UserSetting')]
    param(
        [Parameter(Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('UserSettingId')]
        [string]$Id,

        [switch]$IncludeAssignments
    )

    begin {
        Connect-CloudPC | Out-Null
    }

    process {
        $select = @(
            'id',
            'displayName',
            'selfServiceEnabled',
            'localAdminEnabled',
            'resetEnabled',
            'lastModifiedDateTime',
            'createdDateTime',
            'provisioningSourceType',
            'restorePointSetting',
            'crossRegionDisasterRecoverySetting',
            'notificationSetting'
        ) -join ','

        $query = @('$select=' + [uri]::EscapeDataString($select))
        if ($IncludeAssignments) {
            $query += '$expand=assignments'
        }

        if ($Id) {
            $escapedId = [uri]::EscapeDataString($Id)
            $uri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/userSettings/' +
                   $escapedId + '?' + ($query -join '&')

            try {
                $settings = @( Invoke-MgGraphRequest -Method GET -Uri $uri )
            }
            catch {
                Write-Error "Cloud PC user setting '$Id' not found: $($_.Exception.Message)"
                return
            }
        }
        else {
            $uri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/userSettings?' +
                   ($query -join '&')
            $settings = Invoke-GraphPaged -Uri $uri
        }

        foreach ($setting in $settings) {
            [pscustomobject]@{
                PSTypeName                                    = 'WindowsCloudPC.UserSetting'
                Id                                            = $setting.id
                DisplayName                                   = $setting.displayName
                SelfServiceEnabled                            = $setting.selfServiceEnabled
                LocalAdminEnabled                             = $setting.localAdminEnabled
                ResetEnabled                                  = $setting.resetEnabled
                RestorePointFrequencyInHours                  = $setting.restorePointSetting.frequencyInHours
                RestorePointFrequencyType                     = $setting.restorePointSetting.frequencyType
                UserRestoreEnabled                            = $setting.restorePointSetting.userRestoreEnabled
                CrossRegionDisasterRecoveryEnabled            = $setting.crossRegionDisasterRecoverySetting.crossRegionDisasterRecoveryEnabled
                MaintainCrossRegionRestorePointEnabled        = $setting.crossRegionDisasterRecoverySetting.maintainCrossRegionRestorePointEnabled
                DisasterRecoveryType                          = $setting.crossRegionDisasterRecoverySetting.disasterRecoveryType
                UserInitiatedDisasterRecoveryAllowed          = $setting.crossRegionDisasterRecoverySetting.userInitiatedDisasterRecoveryAllowed
                DisasterRecoveryNetworkSetting                = $setting.crossRegionDisasterRecoverySetting.disasterRecoveryNetworkSetting
                RestartPromptsDisabled                        = $setting.notificationSetting.restartPromptsDisabled
                ProvisioningSourceType                        = $setting.provisioningSourceType
                CreatedDateTime                               = if ($setting.createdDateTime) { ([datetime]$setting.createdDateTime).ToLocalTime() } else { $null }
                LastModifiedDateTime                          = if ($setting.lastModifiedDateTime) { ([datetime]$setting.lastModifiedDateTime).ToLocalTime() } else { $null }
                RestorePointSetting                           = $setting.restorePointSetting
                CrossRegionDisasterRecoverySetting            = $setting.crossRegionDisasterRecoverySetting
                NotificationSetting                           = $setting.notificationSetting
                Assignments                                   = if ($IncludeAssignments) { @($setting.assignments) } else { $null }
                Raw                                           = $setting
            }
        }
    }

    end { }
}

