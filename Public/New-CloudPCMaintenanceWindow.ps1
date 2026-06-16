function New-CloudPCMaintenanceWindow {
    <#
    .SYNOPSIS
        Creates a Windows 365 Cloud PC maintenance window.

    .DESCRIPTION
        Creates a Cloud PC maintenance window by calling Microsoft Graph beta:
        POST /deviceManagement/virtualEndpoint/maintenanceWindows.

        Use the weekday and weekend parameters for the common Intune portal model,
        or pass one or more schedule objects with -Schedule for newer Graph schedule
        types. Each schedule must be at least two hours long.

        Pass -GroupId to assign the created maintenance window to Microsoft Entra
        groups after creation.

    .PARAMETER DisplayName
        Display name for the maintenance window.

    .PARAMETER Description
        Optional description.

    .PARAMETER NotificationLeadTimeInMinutes
        Number of minutes before the maintenance window opens that users are notified.
        Defaults to 60.

    .PARAMETER WeekdayStartTime
        Start time for the weekday schedule in HH:mm format.

    .PARAMETER WeekdayEndTime
        End time for the weekday schedule in HH:mm format.

    .PARAMETER WeekendStartTime
        Optional start time for the weekend schedule in HH:mm format.
        If omitted, the weekday start time is used for the weekend schedule.

    .PARAMETER WeekendEndTime
        Optional end time for the weekend schedule in HH:mm format.
        If omitted, the weekday end time is used for the weekend schedule.

    .PARAMETER Schedule
        One or more hashtables or objects with scheduleType, startTime, and endTime.
        Times may be HH:mm or Graph time-of-day values such as 01:00:00.0000000.

    .PARAMETER GroupId
        Microsoft Entra group IDs to assign after the maintenance window is created.

    .PARAMETER Force
        Suppress confirmation prompts. Equivalent to -Confirm:$false.

    .EXAMPLE
        New-CloudPCMaintenanceWindow -DisplayName 'Off-Hours Window' -WeekdayStartTime '01:00' -WeekdayEndTime '05:00' -Force

        Creates a maintenance window with matching weekday and weekend schedules.

    .EXAMPLE
        New-CloudPCMaintenanceWindow -DisplayName 'Resize Window' -WeekdayStartTime '01:00' -WeekdayEndTime '05:00' -GroupId '<group-id>' -Force

        Creates a maintenance window and assigns it to a Microsoft Entra group.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'Convenience')]
    [OutputType('WindowsCloudPC.MaintenanceWindowCreateResult')]
    param(
        [Parameter(Mandatory)]
        [string]$DisplayName,

        [string]$Description,

        [ValidateRange(0, 1440)]
        [int]$NotificationLeadTimeInMinutes = 60,

        [Parameter(Mandatory, ParameterSetName = 'Convenience')]
        [ValidatePattern('^\d{2}:\d{2}$')]
        [string]$WeekdayStartTime,

        [Parameter(Mandatory, ParameterSetName = 'Convenience')]
        [ValidatePattern('^\d{2}:\d{2}$')]
        [string]$WeekdayEndTime,

        [Parameter(ParameterSetName = 'Convenience')]
        [ValidatePattern('^\d{2}:\d{2}$')]
        [string]$WeekendStartTime,

        [Parameter(ParameterSetName = 'Convenience')]
        [ValidatePattern('^\d{2}:\d{2}$')]
        [string]$WeekendEndTime,

        [Parameter(Mandatory, ParameterSetName = 'BySchedule')]
        [object[]]$Schedule,

        [string[]]$GroupId = @(),

        [switch]$Force
    )

    begin {
        if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = 'None'
        }

        Connect-CloudPC -AdditionalScopes 'CloudPC.ReadWrite.All' | Out-Null
    }

    process {
        if ([string]::IsNullOrWhiteSpace($DisplayName)) {
            Write-Error 'New-CloudPCMaintenanceWindow: DisplayName is required.'
            return
        }

        if ($PSCmdlet.ParameterSetName -eq 'Convenience') {
            if ($PSBoundParameters.ContainsKey('WeekendStartTime') -xor $PSBoundParameters.ContainsKey('WeekendEndTime')) {
                Write-Error 'New-CloudPCMaintenanceWindow: WeekendStartTime and WeekendEndTime must be specified together.'
                return
            }

            $effectiveWeekendStartTime = if ($PSBoundParameters.ContainsKey('WeekendStartTime')) { $WeekendStartTime } else { $WeekdayStartTime }
            $effectiveWeekendEndTime = if ($PSBoundParameters.ContainsKey('WeekendEndTime')) { $WeekendEndTime } else { $WeekdayEndTime }

            $schedules = @(
                @{
                    scheduleType = 'weekday'
                    startTime    = $WeekdayStartTime
                    endTime      = $WeekdayEndTime
                }
                @{
                    scheduleType = 'weekend'
                    startTime    = $effectiveWeekendStartTime
                    endTime      = $effectiveWeekendEndTime
                }
            )
        }
        else {
            $schedules = @($Schedule)
        }

        $normalizedSchedules = @(
            foreach ($item in $schedules) {
                $scheduleHash = if ($item -is [System.Collections.IDictionary]) {
                    $item
                }
                else {
                    $item | ConvertTo-Json -Depth 10 | ConvertFrom-Json -AsHashtable
                }

                foreach ($requiredProperty in @('scheduleType','startTime','endTime')) {
                    if (-not $scheduleHash.ContainsKey($requiredProperty) -or [string]::IsNullOrWhiteSpace([string]$scheduleHash[$requiredProperty])) {
                        Write-Error "New-CloudPCMaintenanceWindow: each schedule requires $requiredProperty."
                        return
                    }
                }

                $startTime = ConvertTo-CloudPCMaintenanceWindowTime -Value $scheduleHash['startTime'] -PropertyName 'startTime'
                $endTime = ConvertTo-CloudPCMaintenanceWindowTime -Value $scheduleHash['endTime'] -PropertyName 'endTime'
                if (-not $startTime -or -not $endTime) {
                    return
                }

                $duration = $endTime - $startTime
                if ($duration.TotalMinutes -le 0) {
                    $duration = $duration.Add([timespan]::FromDays(1))
                }
                if ($duration.TotalMinutes -lt 120) {
                    Write-Error "New-CloudPCMaintenanceWindow: schedule '$($scheduleHash['scheduleType'])' must be at least two hours long."
                    return
                }

                [ordered]@{
                    scheduleType = [string]$scheduleHash['scheduleType']
                    startTime    = $startTime.ToString('hh\:mm\:ss\.fff')
                    endTime      = $endTime.ToString('hh\:mm\:ss\.fff')
                }
            }
        )

        if ($normalizedSchedules.Count -eq 0) {
            Write-Error 'New-CloudPCMaintenanceWindow: at least one schedule is required.'
            return
        }

        $body = [ordered]@{
            displayName                   = $DisplayName
            description                   = if ($PSBoundParameters.ContainsKey('Description')) { $Description } else { '' }
            notificationLeadTimeInMinutes = $NotificationLeadTimeInMinutes
            schedules                     = @($normalizedSchedules)
        }
        Write-Verbose "New-CloudPCMaintenanceWindow: request body $($body | ConvertTo-Json -Depth 20 -Compress)"

        $created = $null
        $createdId = $null
        $status = 'WhatIf'
        $assignmentStatus = if ($GroupId.Count -gt 0) { 'WhatIf' } else { 'Skipped' }
        $assignmentsApplied = 0
        $errorMessage = $null

        if ($PSCmdlet.ShouldProcess("Cloud PC maintenance window '$DisplayName'", 'Create maintenance window')) {
            try {
                $uri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/maintenanceWindows'
                $created = Invoke-MgGraphRequest -Method POST -Uri $uri -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 20 -Compress)
                $createdId = $created.id
                $status = 'Created'
            }
            catch {
                $status = 'Failed'
                $errorMessage = if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
                Write-Error -Message "New-CloudPCMaintenanceWindow: create failed for '$DisplayName'. $errorMessage" -Exception $_.Exception
            }

            if ($status -eq 'Created' -and $GroupId.Count -gt 0) {
                if ([string]::IsNullOrWhiteSpace($createdId)) {
                    $assignmentStatus = 'Failed'
                    $errorMessage = 'Graph create response did not include an id, so assignments could not be applied.'
                    Write-Error "New-CloudPCMaintenanceWindow: $errorMessage"
                }
                else {
                    try {
                        $assignments = @(
                            foreach ($id in $GroupId) {
                                if ([string]::IsNullOrWhiteSpace($id)) { continue }
                                $group = Resolve-CloudPCGroup -GroupId $id
                                @{
                                    target = @{
                                        groupId     = $id
                                        displayName = $group.DisplayName
                                    }
                                }
                            }
                        )

                        if ($assignments.Count -gt 0) {
                            $escapedId = [uri]::EscapeDataString($createdId)
                            $assignUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/maintenanceWindows/$escapedId/assign"
                            $assignBody = @{ assignments = @($assignments) } | ConvertTo-Json -Depth 20 -Compress
                            Write-Verbose "New-CloudPCMaintenanceWindow: assignment body $assignBody"
                            Invoke-MgGraphRequest -Method POST -Uri $assignUri -ContentType 'application/json' -Body $assignBody | Out-Null
                            $assignmentStatus = 'Assigned'
                            $assignmentsApplied = $assignments.Count
                        }
                        else {
                            $assignmentStatus = 'Skipped'
                        }
                    }
                    catch {
                        $assignmentStatus = 'Failed'
                        $errorMessage = if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
                        Write-Error -Message "New-CloudPCMaintenanceWindow: assignment failed for '$DisplayName'. $errorMessage" -Exception $_.Exception
                    }
                }
            }
        }

        [pscustomobject]@{
            PSTypeName         = 'WindowsCloudPC.MaintenanceWindowCreateResult'
            Id                 = $createdId
            DisplayName        = $DisplayName
            Status             = $status
            AssignmentStatus   = $assignmentStatus
            AssignmentsApplied = $assignmentsApplied
            ErrorMessage       = $errorMessage
            Raw                = $created
        }
    }

    end { }
}
