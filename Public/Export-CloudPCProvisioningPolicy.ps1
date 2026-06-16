function Export-CloudPCProvisioningPolicy {
    <#
    .SYNOPSIS
        Exports a Windows 365 Cloud PC provisioning policy as reusable JSON.

    .DESCRIPTION
        Exports the create-safe provisioning policy body and assignment targets for a
        policy returned by Microsoft Graph beta. Read-only Graph fields are not placed
        in CreateBody, so the JSON can be passed to New-CloudPCProvisioningPolicy.

        Assignments are exported separately because Graph creates the provisioning
        policy first, then assigns it with /provisioningPolicies/{id}/assign.

    .PARAMETER Policy
        A WindowsCloudPC.ProvisioningPolicy object returned by Get-CloudPCProvisioningPolicy.

    .PARAMETER Id
        The provisioning policy ID to export.

    .PARAMETER Path
        Optional JSON file path to write. If omitted, the export object is emitted.

    .PARAMETER Force
        Overwrite Path when it already exists.

    .EXAMPLE
        Get-CloudPCProvisioningPolicy -Id '<policy-id>' |
            Export-CloudPCProvisioningPolicy -Path .\policy.json

    .EXAMPLE
        Export-CloudPCProvisioningPolicy -Id '<policy-id>' |
            New-CloudPCProvisioningPolicy -DisplayName 'Copy of source policy' -WhatIf
    #>
    [CmdletBinding(DefaultParameterSetName = 'ById')]
    [OutputType('WindowsCloudPC.ProvisioningPolicyExport', 'WindowsCloudPC.ProvisioningPolicyExportResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
        [object]$Policy,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ById')]
        [Alias('ProvisioningPolicyId')]
        [string]$Id,

        [string]$Path,

        [switch]$Force
    )

    begin {
        Connect-CloudPC | Out-Null
    }

    process {
        $resolvedPolicy = if ($PSCmdlet.ParameterSetName -eq 'ByObject') {
            if ($Policy.PSObject.Properties['Raw']) {
                $Policy
            }
            elseif ($Policy.PSObject.Properties['Id']) {
                Get-CloudPCProvisioningPolicy -Id $Policy.Id
            }
            else {
                Write-Error 'Export-CloudPCProvisioningPolicy: input object must have a Raw or Id property.'
                return
            }
        }
        else {
            Get-CloudPCProvisioningPolicy -Id $Id
        }

        if (-not $resolvedPolicy) {
            Write-Error 'Export-CloudPCProvisioningPolicy: provisioning policy was not found.'
            return
        }

        $export = ConvertTo-CloudPCProvisioningPolicyExport -Policy $resolvedPolicy

        if ($Path) {
            $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
            if ((Test-Path -Path $resolvedPath) -and -not $Force) {
                Write-Error "Export-CloudPCProvisioningPolicy: '$resolvedPath' already exists. Use -Force to overwrite."
                return
            }

            $parent = Split-Path -Path $resolvedPath -Parent
            if ($parent -and -not (Test-Path -Path $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }

            $export | ConvertTo-Json -Depth 50 | Set-Content -Path $resolvedPath -Encoding utf8NoBOM
            [pscustomobject]@{
                PSTypeName  = 'WindowsCloudPC.ProvisioningPolicyExportResult'
                PolicyId    = $export.SourceId
                DisplayName = $export.DisplayName
                Path        = $resolvedPath
            }
        }
        else {
            $export
        }
    }

    end { }
}

