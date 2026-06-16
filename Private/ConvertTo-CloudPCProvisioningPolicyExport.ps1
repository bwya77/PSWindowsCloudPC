function ConvertTo-CloudPCProvisioningPolicyExport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Policy
    )

    begin {
        $createKeys = @(
            '@odata.type',
            'autopatch',
            'autopilotConfiguration',
            'cloudPcNamingTemplate',
            'description',
            'displayName',
            'domainJoinConfigurations',
            'enableSingleSignOn',
            'imageDisplayName',
            'imageId',
            'imageType',
            'localAdminEnabled',
            'managedBy',
            'microsoftManagedDesktop',
            'provisioningType',
            'userExperienceType',
            'userSettingsPersistenceConfiguration',
            'windowsSetting'
        )
    }

    process {
        $raw = if ($Policy.PSObject.Properties['Raw']) { $Policy.Raw } else { $Policy }
        if (-not $raw) {
            throw 'Provisioning policy export requires a policy object or a normalized policy with a Raw property.'
        }

        $rawHash = $raw | ConvertTo-Json -Depth 50 | ConvertFrom-Json -AsHashtable
        $body = [ordered]@{}
        foreach ($key in $createKeys) {
            if ($rawHash.ContainsKey($key) -and $null -ne $rawHash[$key]) {
                $body[$key] = $rawHash[$key]
            }
        }

        if ($body.Contains('domainJoinConfigurations')) {
            $body['domainJoinConfigurations'] = @(
                foreach ($configuration in @($body['domainJoinConfigurations'])) {
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
                    if ($configuration.ContainsKey('onPremisesConnectionId') -and $null -ne $configuration['onPremisesConnectionId']) {
                        $normalizedConfiguration['onPremisesConnectionId'] = $configuration['onPremisesConnectionId']
                    }
                    if ($configuration.ContainsKey('regionName') -and $configuration['regionName'] -and $configuration['regionName'] -ne 'automatic') {
                        $normalizedConfiguration['regionName'] = $configuration['regionName']
                    }

                    [pscustomobject]$normalizedConfiguration
                }
            )
        }

        if ($body.Contains('windowsSetting')) {
            $windowsSetting = [ordered]@{}
            if ($body['windowsSetting'].ContainsKey('@odata.type')) {
                $windowsSetting['@odata.type'] = $body['windowsSetting']['@odata.type']
            }
            if ($body['windowsSetting'].ContainsKey('locale') -and $body['windowsSetting']['locale']) {
                $windowsSetting['locale'] = $body['windowsSetting']['locale']
            }
            $body['windowsSetting'] = [pscustomobject]$windowsSetting
        }

        if (-not $body.Contains('@odata.type')) {
            $body['@odata.type'] = '#microsoft.graph.cloudPcProvisioningPolicy'
        }

        $normalizedAssignments = if ($rawHash.ContainsKey('assignments')) {
            foreach ($assignment in @($rawHash['assignments'])) {
                if (-not $assignment.ContainsKey('target')) { continue }

                $target = $assignment['target']
                if (-not $target.ContainsKey('groupId') -or [string]::IsNullOrWhiteSpace($target['groupId'])) { continue }

                $groupId = $target['groupId']
                $groupName = $null
                if ($Policy.PSObject.Properties['Assignments']) {
                    $match = @($Policy.Assignments | Where-Object { $_.GroupId -eq $groupId } | Select-Object -First 1)
                    if ($match) { $groupName = $match[0].GroupName }
                }

                $targetType = if ($target.ContainsKey('@odata.type') -and $target['@odata.type']) {
                    [string]$target['@odata.type']
                }
                else {
                    'microsoft.graph.cloudPcManagementGroupAssignmentTarget'
                }

                [pscustomobject]@{
                    PSTypeName     = 'WindowsCloudPC.ProvisioningPolicyAssignmentExport'
                    GroupId        = $groupId
                    GroupName      = $groupName
                    TargetType     = $targetType
                    ServicePlanId           = if ($target.ContainsKey('servicePlanId')) { $target['servicePlanId'] } else { $null }
                    AllotmentLicensesCount  = if ($target.ContainsKey('allotmentLicensesCount')) { $target['allotmentLicensesCount'] } else { $null }
                    AllotmentDisplayName    = if ($target.ContainsKey('allotmentDisplayName')) { $target['allotmentDisplayName'] } else { $null }
                    SourceId                = if ($assignment.ContainsKey('id')) { $assignment['id'] } else { $null }
                }
            }
        }
        else {
            @()
        }

        [pscustomobject]@{
            PSTypeName     = 'WindowsCloudPC.ProvisioningPolicyExport'
            ExportVersion  = 1
            ExportedAt     = (Get-Date).ToUniversalTime().ToString('o')
            SourceId       = if ($rawHash.ContainsKey('id')) { $rawHash['id'] } else { $Policy.Id }
            SourceTenantId = $null
            DisplayName    = if ($body.Contains('displayName')) { $body['displayName'] } else { $Policy.DisplayName }
            CreateBody     = [pscustomobject]$body
            Assignments    = @($normalizedAssignments)
        }
    }

    end { }
}
