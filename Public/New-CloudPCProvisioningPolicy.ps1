function New-CloudPCProvisioningPolicy {
    <#
    .SYNOPSIS
        Creates a Windows 365 Cloud PC provisioning policy from an export.

    .DESCRIPTION
        Creates a new Cloud PC provisioning policy by POSTing the exported CreateBody
        to /beta/deviceManagement/virtualEndpoint/provisioningPolicies.

        Use Export-CloudPCProvisioningPolicy to produce the JSON. Assignment targets
        are included in the export, but are only applied when -Assign is specified.

    .PARAMETER Path
        Path to a JSON file created by Export-CloudPCProvisioningPolicy.

    .PARAMETER InputObject
        Export object created by Export-CloudPCProvisioningPolicy.

    .PARAMETER DisplayName
        Optional replacement display name for the new policy.

    .PARAMETER Description
        Optional replacement description for the new policy.

    .PARAMETER Assign
        Recreate exported assignment targets on the newly created policy.

    .PARAMETER RegionName
        Optional supported region name to use for Microsoft Entra joined policies.
        This overrides exported automatic target geography values.

    .PARAMETER IncludeAutopilotConfiguration
        Include the exported Autopilot configuration in the create request.
        By default, this is omitted because Graph can reject copied device
        preparation profile IDs even when they were returned on the source policy.

    .PARAMETER AllotmentLicensesCount
        Override the exported allotment count for shared by Entra group assignment
        targets. Use this when copying a Flex Shared policy and the source count
        exceeds remaining capacity.

    .PARAMETER Force
        Suppress confirmation prompts. Equivalent to -Confirm:$false.

    .EXAMPLE
        New-CloudPCProvisioningPolicy -Path .\policy.json -DisplayName 'Copied Policy' -WhatIf

    .EXAMPLE
        Export-CloudPCProvisioningPolicy -Id '<policy-id>' |
            New-CloudPCProvisioningPolicy -DisplayName 'Copied Policy' -Assign -Force
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'FromPath')]
    [OutputType('WindowsCloudPC.ProvisioningPolicyCreateResult')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'FromPath')]
        [string]$Path,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'FromObject')]
        [object]$InputObject,

        [string]$DisplayName,

        [string]$Description,

        [string]$RegionName,

        [switch]$IncludeAutopilotConfiguration,

        [ValidateRange(1, [int]::MaxValue)]
        [int]$AllotmentLicensesCount,

        [switch]$Assign,

        [switch]$Force
    )

    begin {
        if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = 'None'
        }

        Connect-CloudPC -AdditionalScopes 'CloudPC.ReadWrite.All' | Out-Null
    }

    process {
        $export = if ($PSCmdlet.ParameterSetName -eq 'FromPath') {
            $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
            if (-not (Test-Path -Path $resolvedPath)) {
                Write-Error "New-CloudPCProvisioningPolicy: export file '$resolvedPath' was not found."
                return
            }
            Get-Content -Path $resolvedPath -Raw | ConvertFrom-Json
        }
        else {
            $InputObject
        }

        if (-not $export.PSObject.Properties['CreateBody']) {
            Write-Error 'New-CloudPCProvisioningPolicy: input must be an export object with a CreateBody property.'
            return
        }

        $body = $export.CreateBody | ConvertTo-Json -Depth 50 | ConvertFrom-Json -AsHashtable
        if ($PSBoundParameters.ContainsKey('DisplayName')) {
            $body['displayName'] = $DisplayName
        }
        if ($PSBoundParameters.ContainsKey('Description')) {
            $body['description'] = $Description
        }
        elseif (-not $body.ContainsKey('description') -or $null -eq $body['description']) {
            $body['description'] = ''
        }

        if ($body.ContainsKey('domainJoinConfigurations')) {
            $body['domainJoinConfigurations'] = @(
                foreach ($configuration in @($body['domainJoinConfigurations'])) {
                    if ($configuration -isnot [System.Collections.IDictionary]) {
                        $configuration = $configuration | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
                    }

                    $joinType = if ($configuration.ContainsKey('domainJoinType')) {
                        $configuration['domainJoinType']
                    }
                    elseif ($configuration.ContainsKey('type')) {
                        $configuration['type']
                    }
                    else {
                        $null
                    }

                    $normalizedConfiguration = [ordered]@{}
                    if ($configuration.ContainsKey('@odata.type')) {
                        $normalizedConfiguration['@odata.type'] = $configuration['@odata.type']
                    }
                    if ($joinType) {
                        $normalizedConfiguration['domainJoinType'] = $joinType
                    }
                    if ($configuration.ContainsKey('onPremisesConnectionId') -and $configuration['onPremisesConnectionId']) {
                        $normalizedConfiguration['onPremisesConnectionId'] = $configuration['onPremisesConnectionId']
                    }

                    $effectiveRegionName = if ($PSBoundParameters.ContainsKey('RegionName')) {
                        $RegionName
                    }
                    elseif ($configuration.ContainsKey('regionName') -and $configuration['regionName'] -and $configuration['regionName'] -ne 'automatic') {
                        $configuration['regionName']
                    }
                    else {
                        $null
                    }

                    if ($effectiveRegionName) {
                        $normalizedConfiguration['regionName'] = $effectiveRegionName
                    }

                    [pscustomobject]$normalizedConfiguration
                }
            )
        }

        if (-not $IncludeAutopilotConfiguration -and $body.ContainsKey('autopilotConfiguration')) {
            $body.Remove('autopilotConfiguration')
        }

        if (-not $body.ContainsKey('displayName') -or [string]::IsNullOrWhiteSpace($body['displayName'])) {
            Write-Error 'New-CloudPCProvisioningPolicy: CreateBody.displayName is required. Use -DisplayName to provide one.'
            return
        }

        $missingRequiredProperties = @(
            foreach ($requiredProperty in @('domainJoinConfigurations','imageDisplayName','imageId','imageType','provisioningType','windowsSetting')) {
                if (-not $body.ContainsKey($requiredProperty) -or $null -eq $body[$requiredProperty]) {
                    $requiredProperty
                }
            }
        )

        if ($missingRequiredProperties.Count -gt 0) {
            Write-Error "New-CloudPCProvisioningPolicy: CreateBody is missing required Graph create field(s): $($missingRequiredProperties -join ', '). Re-export the policy with Export-CloudPCProvisioningPolicy and try again."
            return
        }

        $target = "Cloud PC provisioning policy '$($body['displayName'])'"
        $created = $null
        $status = 'WhatIf'
        $assignStatus = if ($Assign) { 'WhatIf' } else { 'Skipped' }
        $assignmentsApplied = 0
        $errorMessage = $null

        if ($PSCmdlet.ShouldProcess($target, 'Create provisioning policy')) {
            try {
                $uri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies'
                $created = Invoke-MgGraphRequest -Method POST -Uri $uri -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 50 -Compress)
                $status = 'Created'
            }
            catch {
                $status = 'Failed'
                $errorMessage = if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                    $_.ErrorDetails.Message
                }
                else {
                    $_.Exception.Message
                }
                Write-Error -Message "New-CloudPCProvisioningPolicy: create failed for $target. $errorMessage" -Exception $_.Exception
            }
        }

        if ($created -and $Assign) {
            $createdId = $created.id
            $assignmentExports = @($export.Assignments)
            if (-not $createdId) {
                $assignStatus = 'Failed'
                $errorMessage = 'Graph create response did not include an id, so assignments could not be applied.'
                Write-Error "New-CloudPCProvisioningPolicy: $errorMessage"
            }
            elseif ($assignmentExports.Count -eq 0) {
                $assignStatus = 'Skipped'
            }
            else {
                $buildAssignments = {
                    param(
                        [bool]$IncludeAssignmentId
                    )

                    foreach ($assignment in $assignmentExports) {
                        if (-not $assignment.GroupId) { continue }
                        $targetType = if ($assignment.TargetType) { [string]$assignment.TargetType } else { 'microsoft.graph.cloudPcManagementGroupAssignmentTarget' }
                        $targetType = $targetType.TrimStart('#')

                        $assignmentBody = [ordered]@{
                            target = [ordered]@{
                                '@odata.type' = $targetType
                                groupId       = $assignment.GroupId
                            }
                        }

                        if ($assignment.PSObject.Properties['ServicePlanId'] -and $assignment.ServicePlanId) {
                            $assignmentBody.target['servicePlanId'] = $assignment.ServicePlanId
                        }
                        $effectiveAllotmentLicensesCount = if ($PSBoundParameters.ContainsKey('AllotmentLicensesCount')) {
                            $AllotmentLicensesCount
                        }
                        elseif ($assignment.PSObject.Properties['AllotmentLicensesCount'] -and $null -ne $assignment.AllotmentLicensesCount) {
                            $assignment.AllotmentLicensesCount
                        }
                        else {
                            $null
                        }

                        if ($null -ne $effectiveAllotmentLicensesCount) {
                            $assignmentBody.target['allotmentLicensesCount'] = $effectiveAllotmentLicensesCount
                        }
                        if ($assignment.PSObject.Properties['AllotmentDisplayName'] -and $assignment.AllotmentDisplayName) {
                            $assignmentBody.target['allotmentDisplayName'] = $assignment.AllotmentDisplayName
                        }

                        if ($IncludeAssignmentId) {
                            $assignmentBody['id'] = "$createdId`_$($assignment.GroupId)"
                        }

                        $assignmentBody
                    }
                }

                $includeAssignmentId = $body['provisioningType'] -eq 'dedicated'
                $assignments = @(& $buildAssignments -IncludeAssignmentId $includeAssignmentId)

                if ($body['provisioningType'] -ne 'dedicated') {
                    $missingServicePlanAssignments = @($assignments | Where-Object { -not $_.target.Contains('servicePlanId') -or -not $_.target['servicePlanId'] })
                    if ($missingServicePlanAssignments.Count -gt 0) {
                        $assignStatus = 'Failed'
                        $errorMessage = "Shared provisioning policy assignments require servicePlanId. Re-export the source policy with Export-CloudPCProvisioningPolicy and try again."
                        Write-Error "New-CloudPCProvisioningPolicy: $errorMessage"
                        $assignments = @()
                    }
                }
                if ($body['provisioningType'] -eq 'sharedByEntraGroup') {
                    $missingAllotmentAssignments = @($assignments | Where-Object { -not $_.target.Contains('allotmentLicensesCount') -or $null -eq $_.target['allotmentLicensesCount'] })
                    if ($missingAllotmentAssignments.Count -gt 0) {
                        $assignStatus = 'Failed'
                        $errorMessage = "Shared by Entra group provisioning policy assignments require allotmentLicensesCount. Re-export the source policy with Export-CloudPCProvisioningPolicy and try again."
                        Write-Error "New-CloudPCProvisioningPolicy: $errorMessage"
                        $assignments = @()
                    }
                }

                if ($assignments.Count -gt 0) {
                    $assignTarget = "Assignments for Cloud PC provisioning policy '$($body['displayName'])'"
                    if ($PSCmdlet.ShouldProcess($assignTarget, 'Assign provisioning policy to exported groups')) {
                        try {
                            $escapedId = [uri]::EscapeDataString($createdId)
                            $assignUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies/$escapedId/assign"
                            Invoke-MgGraphRequest -Method POST -Uri $assignUri -ContentType 'application/json' -Body (@{ assignments = @($assignments) } | ConvertTo-Json -Depth 20 -Compress) | Out-Null
                            $assignStatus = 'Assigned'
                            $assignmentsApplied = $assignments.Count
                        }
                        catch {
                            $assignStatus = 'Failed'
                            $errorMessage = if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                                $_.ErrorDetails.Message
                            }
                            else {
                                $_.Exception.Message
                            }

                            if ($includeAssignmentId -and $errorMessage -match 'Invalid properties:\s*Id') {
                                try {
                                    $assignments = @(& $buildAssignments -IncludeAssignmentId $false)
                                    Invoke-MgGraphRequest -Method POST -Uri $assignUri -ContentType 'application/json' -Body (@{ assignments = @($assignments) } | ConvertTo-Json -Depth 20 -Compress) | Out-Null
                                    $assignStatus = 'Assigned'
                                    $assignmentsApplied = $assignments.Count
                                    $errorMessage = $null
                                }
                                catch {
                                    $errorMessage = if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                                        $_.ErrorDetails.Message
                                    }
                                    else {
                                        $_.Exception.Message
                                    }
                                    Write-Error -Message "New-CloudPCProvisioningPolicy: assignment failed for $target. $errorMessage" -Exception $_.Exception
                                }
                            }
                            else {
                                Write-Error -Message "New-CloudPCProvisioningPolicy: assignment failed for $target. $errorMessage" -Exception $_.Exception
                            }
                        }
                    }
                }
            }
        }

        [pscustomobject]@{
            PSTypeName          = 'WindowsCloudPC.ProvisioningPolicyCreateResult'
            SourceId            = $export.SourceId
            Id                  = if ($created) { $created.id } else { $null }
            DisplayName         = $body['displayName']
            Status              = $status
            AssignmentStatus    = $assignStatus
            AssignmentsApplied  = $assignmentsApplied
            ErrorMessage        = $errorMessage
            Raw                 = $created
        }
    }

    end { }
}
