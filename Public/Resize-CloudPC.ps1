function Resize-CloudPC {
    <#
    .SYNOPSIS
        Resizes one or more Windows 365 Cloud PCs to a target service plan.

    .DESCRIPTION
        Issues POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/resize against Microsoft Graph v1.0
        to upgrade or downgrade a Cloud PC to a target service plan with a different vCPU and storage
        configuration. Graph returns 204 No Content when the asynchronous resize request is accepted.

        When -UseMaintenanceWindow is specified, the cmdlet creates a Microsoft Graph beta
        cloudPcBulkResize action instead: POST /deviceManagement/virtualEndpoint/bulkActions with
        scheduledDuringMaintenanceWindow set to true. This routes one or more Cloud PCs through
        assigned Cloud PC maintenance windows.

        The resize action requires the CloudPC.ReadWrite.All scope. No Microsoft.Graph.DeviceManagement.Administration
        module dependency is required because WindowsCloudPC sends the request through Invoke-MgGraphRequest
        from Microsoft.Graph.Authentication.

        The target service plan can be supplied by ID, exact display name, or a WindowsCloudPC.ServicePlan
        object returned by Get-CloudPCServicePlan.

    .PARAMETER CloudPC
        A WindowsCloudPC.CloudPC object returned by Get-CloudPC, or an exact Cloud PC name, Cloud PC ID,
        managed device ID, Azure AD device ID, or assigned user principal name. Accepts pipeline input.

    .PARAMETER Id
        The Cloud PC ID when you do not have a CloudPC object available.

    .PARAMETER TargetServicePlanId
        The target Windows 365 service plan ID. Alias: ServicePlanId.

    .PARAMETER TargetServicePlanName
        The exact display name of the target Windows 365 service plan. The cmdlet resolves it with
        Get-CloudPCServicePlan before sending the resize request.

    .PARAMETER TargetServicePlan
        A WindowsCloudPC.ServicePlan object returned by Get-CloudPCServicePlan.

    .PARAMETER Force
        Suppress confirmation prompts. Equivalent to -Confirm:$false.

    .PARAMETER UseMaintenanceWindow
        Create a Microsoft Graph beta cloudPcBulkResize action and schedule it according to assigned
        Cloud PC maintenance windows. Pipeline input is collected and submitted as one bulk action.

    .PARAMETER PassThru
        Emit a WindowsCloudPC.ResizeResult object describing the accepted resize request. By default
        the cmdlet is silent on success.

    .EXAMPLE
        Get-CloudPC -Name 'CPC-BRAD-01' |
            Resize-CloudPC -TargetServicePlanName 'Cloud PC Enterprise 4vCPU/16GB/128GB' -WhatIf

        Previews resizing a Cloud PC to a target service plan by exact display name.

    .EXAMPLE
        Resize-CloudPC -Id 'b0a9cde2-e170-4dd9-97c3-ad1d3328a711' `
            -TargetServicePlanId '30d0e128-de93-41dc-89ec-33d84bb662a0' `
            -Force `
            -PassThru

        Sends a resize request for a single Cloud PC by ID and emits the request result.

    .EXAMPLE
        $plan = Get-CloudPCServicePlan -DisplayName 'Cloud PC Enterprise 8vCPU/32GB/256GB'
        Get-CloudPC -Type Dedicated | Resize-CloudPC -TargetServicePlan $plan -WhatIf

        Resolves a target service plan object once, then previews resizing every dedicated Cloud PC.

    .EXAMPLE
        Resize-CloudPC -CloudPC 'CPC-ENT-0M94O' `
            -ServicePlanId '9ecf691d-8b82-46cb-b254-cd061b2c02fb' `
            -UseMaintenanceWindow `
            -PassThru

        Submits a single Cloud PC resize as a bulk resize action that uses assigned maintenance windows.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByObject')]
    [OutputType('WindowsCloudPC.ResizeResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
        [object]$CloudPC,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ById')]
        [Alias('CloudPcId')]
        [string]$Id,

        [Alias('ServicePlanId')]
        [string]$TargetServicePlanId,

        [Alias('ServicePlanName','TargetSku','Sku')]
        [string]$TargetServicePlanName,

        [PSTypeName('WindowsCloudPC.ServicePlan')]
        [object]$TargetServicePlan,

        [switch]$Force,

        [switch]$UseMaintenanceWindow,

        [switch]$PassThru
    )

    begin {
        if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = 'None'
        }

        Connect-CloudPC -AdditionalScopes 'CloudPC.ReadWrite.All' | Out-Null

        $resolvedTargetPlanId = $null
        $resolvedTargetPlanName = $null
        $maintenanceWindowTargets = [System.Collections.Generic.List[object]]::new()

        if ($PSBoundParameters.ContainsKey('TargetServicePlan')) {
            if (-not $TargetServicePlan.Id) {
                throw 'Resize-CloudPC: TargetServicePlan must include an Id property.'
            }

            $resolvedTargetPlanId = $TargetServicePlan.Id
            $resolvedTargetPlanName = if ($TargetServicePlan.DisplayName) { $TargetServicePlan.DisplayName } else { $TargetServicePlan.Id }
        }
        elseif ($PSBoundParameters.ContainsKey('TargetServicePlanId')) {
            if ([string]::IsNullOrWhiteSpace($TargetServicePlanId)) {
                throw 'Resize-CloudPC: TargetServicePlanId is empty.'
            }

            $resolvedTargetPlanId = $TargetServicePlanId
            $resolvedTargetPlanName = $TargetServicePlanId
        }
        elseif ($PSBoundParameters.ContainsKey('TargetServicePlanName')) {
            if ([string]::IsNullOrWhiteSpace($TargetServicePlanName)) {
                throw 'Resize-CloudPC: TargetServicePlanName is empty.'
            }

            $matches = @(Get-CloudPCServicePlan -DisplayName $TargetServicePlanName)
            if ($matches.Count -eq 0) {
                throw "Resize-CloudPC: Target service plan '$TargetServicePlanName' was not found."
            }
            if ($matches.Count -gt 1) {
                throw "Resize-CloudPC: Target service plan '$TargetServicePlanName' matched more than one service plan. Use -TargetServicePlanId."
            }

            $resolvedTargetPlanId = $matches[0].Id
            $resolvedTargetPlanName = $matches[0].DisplayName
        }
        else {
            throw 'Resize-CloudPC: Supply -TargetServicePlanId, -TargetServicePlanName, or -TargetServicePlan.'
        }
    }

    process {
        try {
            $targetPc = if ($PSCmdlet.ParameterSetName -eq 'ById') {
                Resolve-CloudPCTarget -Id $Id -CommandName 'Resize-CloudPC'
            }
            else {
                Resolve-CloudPCTarget -CloudPC $CloudPC -CommandName 'Resize-CloudPC'
            }
        }
        catch {
            Write-Error -ErrorRecord $_
            return
        }

        $target = "Cloud PC '$($targetPc.Name)' ($($targetPc.Id))"
        $action = if ($UseMaintenanceWindow) {
            "Schedule resize to service plan '$resolvedTargetPlanName' ($resolvedTargetPlanId) through maintenance windows"
        }
        else {
            "Resize to service plan '$resolvedTargetPlanName' ($resolvedTargetPlanId)"
        }
        $requestedAt = [datetime]::Now
        $status = 'Accepted'
        $errorMessage = $null

        if (-not $PSCmdlet.ShouldProcess($target, $action)) {
            if ($PassThru) {
                [pscustomobject]@{
                    PSTypeName            = 'WindowsCloudPC.ResizeResult'
                    CloudPcId             = $targetPc.Id
                    CloudPcName           = $targetPc.Name
                    TargetServicePlanId   = $resolvedTargetPlanId
                    TargetServicePlanName = $resolvedTargetPlanName
                    Status                = 'WhatIf'
                    RequestedAt           = $null
                    ErrorMessage          = $null
                }
            }
            return
        }

        if ($UseMaintenanceWindow) {
            $maintenanceWindowTargets.Add($targetPc)
            return
        }

        $escapedCloudPcId = [uri]::EscapeDataString($targetPc.Id)
        $uri = "https://graph.microsoft.com/v1.0/deviceManagement/virtualEndpoint/cloudPCs/$escapedCloudPcId/resize"
        $body = @{ targetServicePlanId = $resolvedTargetPlanId } | ConvertTo-Json -Depth 4 -Compress

        try {
            Invoke-MgGraphRequest -Method POST -Uri $uri -Body $body -ContentType 'application/json' | Out-Null
            Write-Verbose "Resize-CloudPC: resize accepted for $target"
        }
        catch {
            $status = 'Failed'
            $errorMessage = $_.Exception.Message
            if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                $errorMessage = "$errorMessage $($_.ErrorDetails.Message)"
            }
            Write-Error -Message "Resize-CloudPC: resize failed for $target - $errorMessage" -Exception $_.Exception
        }

        if ($PassThru) {
            [pscustomobject]@{
                PSTypeName            = 'WindowsCloudPC.ResizeResult'
                CloudPcId             = $targetPc.Id
                CloudPcName           = $targetPc.Name
                TargetServicePlanId   = $resolvedTargetPlanId
                TargetServicePlanName = $resolvedTargetPlanName
                Status                = $status
                RequestedAt           = $requestedAt
                ErrorMessage          = $errorMessage
            }
        }
    }

    end {
        if (-not $UseMaintenanceWindow -or $maintenanceWindowTargets.Count -eq 0) {
            return
        }

        $cloudPcIds = @($maintenanceWindowTargets | ForEach-Object { $_.Id })
        $body = @{
            '@odata.type' = '#microsoft.graph.cloudPcBulkResize'
            displayName = "Resize Cloud PCs to $resolvedTargetPlanName"
            cloudPcIds = $cloudPcIds
            targetServicePlanId = $resolvedTargetPlanId
            scheduledDuringMaintenanceWindow = $true
        } | ConvertTo-Json -Depth 5 -Compress
        $uri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/bulkActions'
        $status = 'Accepted'
        $errorMessage = $null
        $requestedAt = [datetime]::Now
        $bulkAction = $null

        try {
            $bulkAction = Invoke-MgGraphRequest -Method POST -Uri $uri -Body $body -ContentType 'application/json'
            Write-Verbose "Resize-CloudPC: maintenance-window bulk resize accepted for $($cloudPcIds.Count) Cloud PC(s)"
            if ($bulkAction.status) {
                $status = $bulkAction.status
            }
        }
        catch {
            $status = 'Failed'
            $errorMessage = $_.Exception.Message
            if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                $errorMessage = "$errorMessage $($_.ErrorDetails.Message)"
            }
            Write-Error -Message "Resize-CloudPC: maintenance-window bulk resize failed for $($cloudPcIds.Count) Cloud PC(s) - $errorMessage" -Exception $_.Exception
        }

        if ($PassThru) {
            foreach ($targetPc in $maintenanceWindowTargets) {
                [pscustomobject]@{
                    PSTypeName                       = 'WindowsCloudPC.ResizeResult'
                    CloudPcId                        = $targetPc.Id
                    CloudPcName                      = $targetPc.Name
                    TargetServicePlanId              = $resolvedTargetPlanId
                    TargetServicePlanName            = $resolvedTargetPlanName
                    Status                           = $status
                    RequestedAt                      = $requestedAt
                    ErrorMessage                     = $errorMessage
                    UseMaintenanceWindow             = $true
                    ScheduledDuringMaintenanceWindow = $true
                    BulkActionId                     = $bulkAction.id
                    RawBulkAction                    = $bulkAction
                }
            }
        }
    }
}
