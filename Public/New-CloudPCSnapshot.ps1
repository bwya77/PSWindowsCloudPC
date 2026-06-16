function New-CloudPCSnapshot {
    <#
    .SYNOPSIS
        Creates restore point snapshots for one or more Windows 365 Cloud PCs.

    .DESCRIPTION
        Calls the Microsoft Graph beta /deviceManagement/virtualEndpoint/cloudPCs/{id}/createSnapshot
        action. Graph returns 204 No Content when the asynchronous snapshot request is accepted.

        Targets can be a single Cloud PC object, a Cloud PC ID, a friendly Cloud PC name,
        all Cloud PCs in the tenant, all Cloud PCs assigned to a user, or all Cloud PCs
        associated with a provisioning policy.

        The cmdlet emits one WindowsCloudPC.SnapshotRequestResult row per target so batch
        runs show exactly which Cloud PCs were invoked.

    .PARAMETER CloudPC
        A WindowsCloudPC.CloudPC object returned by Get-CloudPC, or a Cloud PC friendly name.
        Accepts pipeline input.

    .PARAMETER Id
        The Cloud PC ID when you do not have a CloudPC object available.

    .PARAMETER All
        Creates snapshots for every Cloud PC returned by Get-CloudPC.

    .PARAMETER User
        Creates snapshots for Cloud PCs returned by Get-CloudPC -UserPrincipalName.

    .PARAMETER ProvisioningPolicyId
        Creates snapshots for Cloud PCs associated with a provisioning policy.

    .PARAMETER ExcludeCloudPC
        Cloud PCs to skip. Match values against Cloud PC Id, Name, ManagedDeviceId,
        AadDeviceId, or AssignedUserUpn.

    .PARAMETER StorageAccountId
        Optional storage account ID that receives the restore point.

    .PARAMETER AccessTier
        Optional blob access tier: hot, cool, cold, archive, or unknownFutureValue.

    .PARAMETER Force
        Suppress confirmation prompts. Equivalent to -Confirm:$false.

    .EXAMPLE
        New-CloudPCSnapshot -CloudPC 'CFD-Vance-XS4KT' -Force

        Creates a snapshot for one Cloud PC by friendly name.

    .EXAMPLE
        New-CloudPCSnapshot -User 'user@contoso.com' -Force

        Creates snapshots for every Cloud PC assigned to the user.

    .EXAMPLE
        New-CloudPCSnapshot -ProvisioningPolicyId '<policy-id>' -ExcludeCloudPC 'CPC-KEEP-01','user2@contoso.com' -Force

        Creates snapshots for every Cloud PC in the provisioning policy except the excluded targets.

    .EXAMPLE
        New-CloudPCSnapshot -All -WhatIf

        Shows every Cloud PC that would receive a snapshot without sending requests.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByObject')]
    [OutputType('WindowsCloudPC.SnapshotRequestResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
        [object]$CloudPC,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ById')]
        [Alias('CloudPcId')]
        [string]$Id,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch]$All,

        [Parameter(Mandatory, ParameterSetName = 'ByUser')]
        [Alias('UserPrincipalName','UPN')]
        [string]$User,

        [Parameter(Mandatory, ParameterSetName = 'ByPolicy')]
        [Alias('PolicyId')]
        [string]$ProvisioningPolicyId,

        [Parameter(ParameterSetName = 'All')]
        [Parameter(ParameterSetName = 'ByUser')]
        [Parameter(ParameterSetName = 'ByPolicy')]
        [Alias('Exclude','ExcludeId','ExcludeName')]
        [string[]]$ExcludeCloudPC = @(),

        [string]$StorageAccountId,

        [ValidateSet('hot','cool','cold','archive','unknownFutureValue')]
        [string]$AccessTier,

        [switch]$Force
    )

    begin {
        if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = 'None'
        }

        Connect-CloudPC -AdditionalScopes 'CloudPC.ReadWrite.All' | Out-Null

        $excludeSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($item in @($ExcludeCloudPC)) {
            if (-not [string]::IsNullOrWhiteSpace($item)) {
                $null = $excludeSet.Add($item.Trim())
            }
        }
    }

    process {
        $targets = @()
        $policyDisplayName = $null

        switch ($PSCmdlet.ParameterSetName) {
            'All' {
                Write-Verbose "Retrieving all Cloud PCs."
                $targets = @(Get-CloudPC)
                Write-Verbose "Found $($targets.Count) Cloud PC(s)."
            }
            'ByUser' {
                Write-Verbose "Retrieving Cloud PCs for user '$User'."
                $targets = @(Get-CloudPC -UserPrincipalName $User)
                Write-Verbose "Found $($targets.Count) Cloud PC(s) for user '$User'."
            }
            'ByPolicy' {
                Write-Verbose "Retrieving Cloud PCs for provisioning policy '$ProvisioningPolicyId'."
                $policy = Get-CloudPCByProvisioningPolicy -ProvisioningPolicyId $ProvisioningPolicyId
                if (-not $policy) {
                    Write-Error "New-CloudPCSnapshot: provisioning policy '$ProvisioningPolicyId' was not found."
                    return
                }
                $targets = @($policy.CloudPCs)
                $policyDisplayName = $policy.DisplayName
                Write-Verbose "Found $($targets.Count) Cloud PC(s) in provisioning policy '$($policy.DisplayName)' ($ProvisioningPolicyId)."
            }
            'ByObject' {
                if ($CloudPC -is [string]) {
                    Write-Verbose "Resolving Cloud PC name '$CloudPC'."
                    $matches = @(Get-CloudPC | Where-Object {
                        $_.Name -eq $CloudPC -or
                        $_.Id -eq $CloudPC -or
                        $_.ManagedDeviceId -eq $CloudPC -or
                        $_.AadDeviceId -eq $CloudPC -or
                        $_.AssignedUserUpn -eq $CloudPC
                    })

                    if ($matches.Count -eq 0) {
                        Write-Error "New-CloudPCSnapshot: Cloud PC '$CloudPC' was not found. Pipe from Get-CloudPC, use -Id, -User, -ProvisioningPolicyId, or -All."
                        return
                    }

                    if ($matches.Count -gt 1) {
                        Write-Error "New-CloudPCSnapshot: Cloud PC '$CloudPC' matched $($matches.Count) Cloud PCs. Pipe the exact object from Get-CloudPC or use -Id."
                        return
                    }

                    $targets = @($matches[0])
                }
                else {
                    $targets = @($CloudPC)
                }
            }
            'ById' {
                $targets = @(
                    [pscustomobject]@{
                        PSTypeName       = 'WindowsCloudPC.CloudPC'
                        Id               = $Id
                        Name             = $Id
                        ManagedDeviceId  = $null
                        AadDeviceId      = $null
                        AssignedUserUpn  = $null
                    }
                )
            }
        }

        if ($targets.Count -eq 0) {
            Write-Error "New-CloudPCSnapshot: no Cloud PCs matched the requested target."
            return
        }

        foreach ($pc in $targets) {
            $cloudPcId = $pc.Id
            $cloudPcName = if ($pc.Name) { $pc.Name } else { $pc.Id }
            $assignedUserUpn = $pc.AssignedUserUpn
            $resultPolicyId = if ($PSCmdlet.ParameterSetName -eq 'ByPolicy') { $ProvisioningPolicyId } else { $pc.ProvisioningPolicyId }
            $resultPolicyName = if ($PSCmdlet.ParameterSetName -eq 'ByPolicy') { $policyDisplayName } else { $pc.ProvisioningPolicyName }

            if (-not $cloudPcId) {
                Write-Error "New-CloudPCSnapshot: Cloud PC Id is empty; nothing to invoke."
                continue
            }

            $matchValues = @(
                $pc.Id
                $pc.Name
                $pc.ManagedDeviceId
                $pc.AadDeviceId
                $pc.AssignedUserUpn
            ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

            $excludedBy = $matchValues | Where-Object { $excludeSet.Contains($_) } | Select-Object -First 1
            if ($excludedBy) {
                [pscustomobject]@{
                    PSTypeName       = 'WindowsCloudPC.SnapshotRequestResult'
                    CloudPcId        = $cloudPcId
                    CloudPcName      = $cloudPcName
                    AssignedUserUpn  = $assignedUserUpn
                    ProvisioningPolicyId   = $resultPolicyId
                    ProvisioningPolicyName = $resultPolicyName
                    Excluded         = $true
                    ExcludedBy       = $excludedBy
                    Status           = 'Excluded'
                    RequestedAt      = $null
                    StorageAccountId = if ($PSBoundParameters.ContainsKey('StorageAccountId')) { $StorageAccountId } else { $null }
                    AccessTier       = if ($PSBoundParameters.ContainsKey('AccessTier')) { $AccessTier } else { $null }
                    ErrorMessage     = $null
                }
                continue
            }

            $target = "Cloud PC '$cloudPcName' ($cloudPcId)"
            if (-not $PSCmdlet.ShouldProcess($target, 'Create snapshot')) {
                [pscustomobject]@{
                    PSTypeName       = 'WindowsCloudPC.SnapshotRequestResult'
                    CloudPcId        = $cloudPcId
                    CloudPcName      = $cloudPcName
                    AssignedUserUpn  = $assignedUserUpn
                    ProvisioningPolicyId   = $resultPolicyId
                    ProvisioningPolicyName = $resultPolicyName
                    Excluded         = $false
                    ExcludedBy       = $null
                    Status           = 'WhatIf'
                    RequestedAt      = $null
                    StorageAccountId = if ($PSBoundParameters.ContainsKey('StorageAccountId')) { $StorageAccountId } else { $null }
                    AccessTier       = if ($PSBoundParameters.ContainsKey('AccessTier')) { $AccessTier } else { $null }
                    ErrorMessage     = $null
                }
                continue
            }

            $body = [ordered]@{}
            if ($PSBoundParameters.ContainsKey('StorageAccountId')) {
                $body.storageAccountId = $StorageAccountId
            }
            if ($PSBoundParameters.ContainsKey('AccessTier')) {
                $body.accessTier = $AccessTier
            }

            $escapedCloudPcId = [uri]::EscapeDataString($cloudPcId)
            $uri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$escapedCloudPcId/createSnapshot"
            $status = 'Accepted'
            $errorMessage = $null

            try {
                Write-Verbose "Creating snapshot for Cloud PC '$cloudPcName' ($cloudPcId)."
                Invoke-MgGraphRequest -Method POST -Uri $uri -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 3 -Compress) | Out-Null
            }
            catch {
                $status = 'Failed'
                $errorMessage = $_.Exception.Message
                Write-Error -Message "New-CloudPCSnapshot: create snapshot failed for $target -- $errorMessage" -Exception $_.Exception
            }

            [pscustomobject]@{
                PSTypeName       = 'WindowsCloudPC.SnapshotRequestResult'
                CloudPcId        = $cloudPcId
                CloudPcName      = $cloudPcName
                AssignedUserUpn  = $assignedUserUpn
                ProvisioningPolicyId   = $resultPolicyId
                ProvisioningPolicyName = $resultPolicyName
                Excluded         = $false
                ExcludedBy       = $null
                Status           = $status
                RequestedAt      = [datetime]::Now
                StorageAccountId = if ($PSBoundParameters.ContainsKey('StorageAccountId')) { $StorageAccountId } else { $null }
                AccessTier       = if ($PSBoundParameters.ContainsKey('AccessTier')) { $AccessTier } else { $null }
                ErrorMessage     = $errorMessage
            }
        }
    }

    end { }
}
