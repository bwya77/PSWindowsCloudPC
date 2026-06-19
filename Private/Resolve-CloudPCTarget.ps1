function Resolve-CloudPCTarget {
    <#
    .SYNOPSIS
        Resolves a Cloud PC object, ID, or friendly identifier to a normalized target.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByObject')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByObject')]
        [object]$CloudPC,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [Alias('CloudPcId')]
        [string]$Id,

        [Parameter(Mandatory)]
        [string]$CommandName
    )

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        if ([string]::IsNullOrWhiteSpace($Id)) {
            throw "${CommandName}: Cloud PC Id is empty."
        }

        return [pscustomobject]@{
            PSTypeName              = 'WindowsCloudPC.CloudPCTarget'
            Id                      = $Id
            Name                    = $Id
            ManagedDeviceId         = $null
            AadDeviceId             = $null
            AssignedUserUpn         = $null
            ProvisioningPolicyId    = $null
            ProvisioningPolicyName  = $null
            Raw                     = $null
        }
    }

    if ($CloudPC -is [string]) {
        if ([string]::IsNullOrWhiteSpace($CloudPC)) {
            throw "${CommandName}: Cloud PC name or Id is empty."
        }

        $matches = @(Get-CloudPC | Where-Object {
            $_.Id -eq $CloudPC -or
            $_.Name -eq $CloudPC -or
            $_.ManagedDeviceId -eq $CloudPC -or
            $_.AadDeviceId -eq $CloudPC -or
            $_.AssignedUserUpn -eq $CloudPC -or
            $_.Raw.managedDeviceName -eq $CloudPC -or
            $_.Raw.displayName -eq $CloudPC
        })

        if ($matches.Count -eq 0) {
            throw "${CommandName}: Cloud PC '$CloudPC' was not found. Pass a Cloud PC object from Get-CloudPC, an exact Cloud PC name, or an Id."
        }
        if ($matches.Count -gt 1) {
            throw "${CommandName}: Cloud PC '$CloudPC' matched more than one object. Pipe the exact object from Get-CloudPC or use -Id."
        }

        $CloudPC = $matches[0]
    }

    if (-not $CloudPC.Id) {
        throw "${CommandName}: Cloud PC Id is empty."
    }

    [pscustomobject]@{
        PSTypeName              = 'WindowsCloudPC.CloudPCTarget'
        Id                      = $CloudPC.Id
        Name                    = if ($CloudPC.Name) { $CloudPC.Name } elseif ($CloudPC.Raw.managedDeviceName) { $CloudPC.Raw.managedDeviceName } elseif ($CloudPC.Raw.displayName) { $CloudPC.Raw.displayName } else { $CloudPC.Id }
        ManagedDeviceId         = $CloudPC.ManagedDeviceId
        AadDeviceId             = $CloudPC.AadDeviceId
        AssignedUserUpn         = $CloudPC.AssignedUserUpn
        ProvisioningPolicyId    = $CloudPC.ProvisioningPolicyId
        ProvisioningPolicyName  = $CloudPC.ProvisioningPolicyName
        Raw                     = $CloudPC.Raw
    }
}
