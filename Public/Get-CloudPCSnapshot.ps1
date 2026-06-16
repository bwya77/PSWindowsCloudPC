function Get-CloudPCSnapshot {
    <#
    .SYNOPSIS
        Returns snapshots for one or more Windows 365 Cloud PCs.

    .DESCRIPTION
        Calls the Microsoft Graph beta /deviceManagement/virtualEndpoint/cloudPCs/{id}/retrieveSnapshots
        endpoint and returns normalized WindowsCloudPC.Snapshot objects.

        The cmdlet accepts Cloud PC objects from Get-CloudPC through the pipeline
        or a Cloud PC ID through -Id. Use -All to retrieve every Cloud PC first
        and return snapshots with friendly Cloud PC names.

    .PARAMETER CloudPC
        A WindowsCloudPC.CloudPC object returned by Get-CloudPC, or a Cloud PC
        friendly name. Accepts pipeline input.

    .PARAMETER Id
        The Cloud PC ID when you do not have a CloudPC object available.

    .PARAMETER All
        Gets all Cloud PCs with Get-CloudPC, then returns snapshots for each one
        with CloudPcName populated from the Cloud PC object.

    .PARAMETER User
        Gets Cloud PCs for the specified user principal name, then returns
        snapshots for each one with CloudPcName populated from the Cloud PC object.

    .PARAMETER ResolveName
        Looks up the Cloud PC when using -Id so CloudPcName contains a friendly
        managed device name or display name instead of the ID.

    .EXAMPLE
        Get-CloudPCSnapshot -Id '8ab4e59b-1866-4ce9-8bc8-92856e61edf4'

        Lists snapshots for a single Cloud PC.

    .EXAMPLE
        Get-CloudPCSnapshot -Id '8ab4e59b-1866-4ce9-8bc8-92856e61edf4' -ResolveName |
            Format-Table CloudPcName,Status,SnapshotType,CreatedDateTime

        Lists snapshots and resolves the Cloud PC friendly name.

    .EXAMPLE
        Get-CloudPCSnapshot -CloudPC 'CFD-Vance-XS4KT'

        Looks up a Cloud PC by friendly name and lists its snapshots.

    .EXAMPLE
        Get-CloudPCSnapshot -User 'user@contoso.com' |
            Format-Table CloudPcName,Status,SnapshotType,CreatedDateTime

        Lists snapshots for Cloud PCs assigned to a user.

    .EXAMPLE
        Get-CloudPCSnapshot -All | Format-Table CloudPcName,Status,SnapshotType,CreatedDateTime

        Lists snapshots for every Cloud PC, including friendly Cloud PC names.

    .EXAMPLE
        Get-CloudPC | Get-CloudPCSnapshot | Format-Table CloudPcName,Status,SnapshotType,CreatedDateTime

        Lists snapshots for every Cloud PC returned by Get-CloudPC.

    .EXAMPLE
        Get-CloudPC -UserPrincipalName 'user@contoso.com' |
            Get-CloudPCSnapshot |
            Sort-Object CreatedDateTime -Descending

        Lists snapshots for a user's Cloud PCs.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByObject')]
    [OutputType('WindowsCloudPC.Snapshot')]
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

        [Parameter(ParameterSetName = 'ById')]
        [switch]$ResolveName
    )

    begin {
        Connect-CloudPC | Out-Null
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'All') {
            Write-Verbose "Retrieving all Cloud PCs."
            $cloudPcs = @(Get-CloudPC)
            Write-Verbose "Found $($cloudPcs.Count) Cloud PC(s)."

            foreach ($pc in $cloudPcs) {
                $pcName = if ($pc.Name) { $pc.Name } else { $pc.Id }
                Write-Verbose "Retrieving snapshots for Cloud PC '$pcName' ($($pc.Id))."
                $snapshots = @($pc | Get-CloudPCSnapshot)
                Write-Verbose "Found $($snapshots.Count) snapshot(s) for Cloud PC '$pcName' ($($pc.Id))."
                $snapshots
            }
            return
        }

        if ($PSCmdlet.ParameterSetName -eq 'ByUser') {
            Write-Verbose "Retrieving Cloud PCs for user '$User'."
            $cloudPcs = @(Get-CloudPC -UserPrincipalName $User)
            Write-Verbose "Found $($cloudPcs.Count) Cloud PC(s) for user '$User'."

            foreach ($pc in $cloudPcs) {
                $pcName = if ($pc.Name) { $pc.Name } else { $pc.Id }
                Write-Verbose "Retrieving snapshots for Cloud PC '$pcName' ($($pc.Id))."
                $snapshots = @($pc | Get-CloudPCSnapshot)
                Write-Verbose "Found $($snapshots.Count) snapshot(s) for Cloud PC '$pcName' ($($pc.Id))."
                $snapshots
            }
            return
        }

        if ($PSCmdlet.ParameterSetName -eq 'ByObject') {
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
                    Write-Error "Get-CloudPCSnapshot: Cloud PC '$CloudPC' was not found. Pipe from Get-CloudPC, use -Id, or use -All."
                    return
                }

                if ($matches.Count -gt 1) {
                    Write-Error "Get-CloudPCSnapshot: Cloud PC '$CloudPC' matched $($matches.Count) Cloud PCs. Pipe the exact object from Get-CloudPC or use -Id."
                    return
                }

                $resolvedCloudPc = $matches[0]
                $cloudPcId = $resolvedCloudPc.Id
                $cloudPcName = if ($resolvedCloudPc.Name) { $resolvedCloudPc.Name } else { $resolvedCloudPc.Id }
                Write-Verbose "Resolved Cloud PC '$CloudPC' to '$cloudPcName' ($cloudPcId)."
            }
            else {
                $cloudPcId = $CloudPC.Id
                $cloudPcName = if ($CloudPC.Name) { $CloudPC.Name } else { $CloudPC.Id }
            }
        }
        else {
            $cloudPcId = $Id
            $cloudPcName = $Id
        }

        if (-not $cloudPcId) {
            Write-Error "Get-CloudPCSnapshot: Cloud PC Id is empty; nothing to query."
            return
        }

        if ($ResolveName -and $PSCmdlet.ParameterSetName -eq 'ById') {
            $escapedNameLookupId = [uri]::EscapeDataString($cloudPcId)
            $nameLookupSelect = [uri]::EscapeDataString('id,managedDeviceName,displayName')
            $nameLookupUri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/' +
                             $escapedNameLookupId +
                             '?$select=' +
                             $nameLookupSelect

            try {
                Write-Verbose "Resolving friendly name for Cloud PC '$cloudPcId'."
                $cloudPc = Invoke-MgGraphRequest -Method GET -Uri $nameLookupUri
                if ($cloudPc.managedDeviceName) {
                    $cloudPcName = $cloudPc.managedDeviceName
                }
                elseif ($cloudPc.displayName) {
                    $cloudPcName = $cloudPc.displayName
                }
                Write-Verbose "Resolved Cloud PC '$cloudPcId' to '$cloudPcName'."
            }
            catch {
                Write-Warning "Get-CloudPCSnapshot: name lookup failed for $cloudPcId -- $($_.Exception.Message)"
            }
        }

        $select = @(
            'id',
            'cloudPcId',
            'status',
            'createdDateTime',
            'lastRestoredDateTime',
            'snapshotType',
            'expirationDateTime',
            'healthCheckStatus'
        ) -join ','

        $escapedCloudPcId = [uri]::EscapeDataString($cloudPcId)
        $uri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/' +
               $escapedCloudPcId +
               '/retrieveSnapshots?$select=' +
               [uri]::EscapeDataString($select)

        try {
            Write-Verbose "Querying snapshots for Cloud PC '$cloudPcName' ($cloudPcId)."
            $resp = Invoke-MgGraphRequest -Method GET -Uri $uri
        }
        catch {
            Write-Error -Message "Get-CloudPCSnapshot: query failed for $cloudPcName ($cloudPcId) -- $($_.Exception.Message)" -Exception $_.Exception
            return
        }

        $snapshots = @($resp.value)
        Write-Verbose "Found $($snapshots.Count) snapshot(s) for Cloud PC '$cloudPcName' ($cloudPcId)."

        $snapshots |
            Sort-Object -Property @{ Expression = { if ($_.createdDateTime) { [datetime]$_.createdDateTime } else { [datetime]::MinValue } }; Descending = $true } |
            ForEach-Object {
                $snapshot = $_

                [pscustomobject]@{
                    PSTypeName           = 'WindowsCloudPC.Snapshot'
                    Id                   = $snapshot.id
                    SnapshotId           = $snapshot.id
                    CloudPcId            = if ($snapshot.cloudPcId) { $snapshot.cloudPcId } else { $cloudPcId }
                    CloudPcName          = $cloudPcName
                    Status               = $snapshot.status
                    SnapshotType         = $snapshot.snapshotType
                    CreatedDateTime      = if ($snapshot.createdDateTime) { ([datetime]$snapshot.createdDateTime).ToLocalTime() } else { $null }
                    LastRestoredDateTime = if ($snapshot.lastRestoredDateTime) { ([datetime]$snapshot.lastRestoredDateTime).ToLocalTime() } else { $null }
                    ExpirationDateTime   = if ($snapshot.expirationDateTime) { ([datetime]$snapshot.expirationDateTime).ToLocalTime() } else { $null }
                    HealthCheckStatus    = $snapshot.healthCheckStatus
                    Raw                  = $snapshot
                }
            }
    }

    end { }
}
