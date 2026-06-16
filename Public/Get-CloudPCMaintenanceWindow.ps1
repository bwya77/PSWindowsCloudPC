function Get-CloudPCMaintenanceWindow {
    <#
    .SYNOPSIS
        Returns Windows 365 Cloud PC maintenance windows.

    .DESCRIPTION
        Wraps Microsoft Graph beta /deviceManagement/virtualEndpoint/maintenanceWindows
        and returns normalized WindowsCloudPC.MaintenanceWindow objects.

        Pass -IncludeAssignments to expand assigned Microsoft Entra groups and resolve
        their display names.

    .PARAMETER Id
        Optional maintenance window ID. Accepts pipeline input by property name.

    .PARAMETER DisplayName
        Optional exact display name filter. Alias: Name.

    .PARAMETER IncludeAssignments
        Expand assignment relationships and resolve assigned group display names.

    .EXAMPLE
        Get-CloudPCMaintenanceWindow | Format-Table DisplayName,ScheduleSummary

        Lists Cloud PC maintenance windows and their schedule summary.

    .EXAMPLE
        Get-CloudPCMaintenanceWindow -DisplayName 'Off-Hours Window' -IncludeAssignments

        Returns one maintenance window by exact display name and includes assigned groups.
    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    [OutputType('WindowsCloudPC.MaintenanceWindow')]
    param(
        [Parameter(Position = 0, ValueFromPipelineByPropertyName, ParameterSetName = 'ById')]
        [Alias('MaintenanceWindowId')]
        [string]$Id,

        [Parameter(ParameterSetName = 'List')]
        [Alias('Name')]
        [string]$DisplayName,

        [switch]$IncludeAssignments
    )

    begin {
        Connect-CloudPC | Out-Null
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ById') {
            if ([string]::IsNullOrWhiteSpace($Id)) {
                Write-Error 'Get-CloudPCMaintenanceWindow: maintenance window Id is empty.'
                return
            }

            $escapedId = [uri]::EscapeDataString($Id)
            $uri = if ($IncludeAssignments) {
                "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/maintenanceWindows/$escapedId`?`$expand=assignments"
            }
            else {
                "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/maintenanceWindows/$escapedId"
            }
            try {
                $windows = @(Invoke-MgGraphRequest -Method GET -Uri $uri)
            }
            catch {
                Write-Error "Get-CloudPCMaintenanceWindow: maintenance window '$Id' was not found. $($_.Exception.Message)"
                return
            }
        }
        else {
            $uri = if ($IncludeAssignments) {
                'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/maintenanceWindows?$expand=assignments'
            }
            else {
                'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/maintenanceWindows'
            }
            $windows = @(Invoke-GraphPaged -Uri $uri)
            if ($PSBoundParameters.ContainsKey('DisplayName')) {
                $windows = @($windows | Where-Object { $_.displayName -eq $DisplayName })
            }
        }

        foreach ($window in $windows) {
            $assignmentInfo = if ($IncludeAssignments) {
                foreach ($assignment in @($window.assignments)) {
                    $groupId = $assignment.target.groupId
                    $groupName = if ($groupId) { (Resolve-CloudPCGroup -GroupId $groupId).DisplayName } else { $null }
                    [pscustomobject]@{
                        GroupId    = $groupId
                        GroupName  = $groupName
                        TargetType = $assignment.target.'@odata.type'
                    }
                }
            }
            else {
                $null
            }

            $scheduleInfo = @($window.schedules | ForEach-Object {
                    $scheduleType = if ($_.scheduleType) { $_.scheduleType } else { 'schedule' }
                    "$scheduleType $($_.startTime)-$($_.endTime)"
                })

            [pscustomobject]@{
                PSTypeName                    = 'WindowsCloudPC.MaintenanceWindow'
                Id                            = $window.id
                MaintenanceWindowId           = $window.id
                DisplayName                   = $window.displayName
                Description                   = $window.description
                NotificationLeadTimeInMinutes = $window.notificationLeadTimeInMinutes
                Schedules                     = @($window.schedules)
                ScheduleSummary               = $scheduleInfo -join '; '
                Assignments                   = if ($IncludeAssignments) { @($assignmentInfo) } else { $null }
                AssignedGroupIds              = if ($IncludeAssignments) { @($assignmentInfo | Where-Object { $_.GroupId } | Select-Object -ExpandProperty GroupId) } else { $null }
                AssignedGroupNames            = if ($IncludeAssignments) { @($assignmentInfo | Where-Object { $_.GroupName } | Select-Object -ExpandProperty GroupName) } else { $null }
                Raw                           = $window
            }
        }
    }

    end { }
}
