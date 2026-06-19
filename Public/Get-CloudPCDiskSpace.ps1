function Get-CloudPCDiskSpace {
    <#
    .SYNOPSIS
        Reports OS disk capacity and free space for Windows 365 Cloud PCs.

    .DESCRIPTION
        Joins Windows 365 Cloud PC inventory with the associated Intune
        managedDevice record and calculates total storage, free storage, used
        storage, percent free, and percent used for the Cloud PC OS disk.

        Microsoft Graph exposes disk metrics on the
        https://graph.microsoft.com/beta/deviceManagement/managedDevices
        endpoint, not on the cloudPC resource. The values come from Intune
        inventory and reflect the device's last check-in time, shown as
        LastSyncDateTime.

    .PARAMETER CloudPC
        Pipe in WindowsCloudPC.CloudPC objects from Get-CloudPC, or pass one or
        more Cloud PC IDs or names. String values are resolved against Get-CloudPC
        using exact matches on Id, Name, managedDeviceId, managedDeviceName, or
        displayName.

    .PARAMETER ProvisioningPolicyId
        Limit the report to a single provisioning policy.

    .PARAMETER Type
        Shared, Dedicated, or All (default).

    .EXAMPLE
        Get-CloudPCDiskSpace |
            Sort-Object PercentFree |
            Format-Table CloudPcName,FreeStorageGB,TotalStorageGB,PercentFree,LastSyncDateTime

    .EXAMPLE
        Get-CloudPC -Type Dedicated | Get-CloudPCDiskSpace

    .EXAMPLE
        Get-CloudPCDiskSpace -CloudPC '<cloud-pc-id-or-name>'

    .EXAMPLE
        Get-CloudPCDiskSpace |
            Where-Object PercentFree -lt 15 |
            Format-Table CloudPcName,AssignedUserUpn,FreeStorageGB,PercentFree
    #>
    [CmdletBinding()]
    [OutputType('WindowsCloudPC.CloudPCDiskSpace')]
    param(
        [Parameter(ValueFromPipeline)]
        [object[]]$CloudPC,

        [string]$ProvisioningPolicyId,

        [ValidateSet('Shared','Dedicated','All')]
        [string]$Type = 'All'
    )

    begin {
        Connect-CloudPC | Out-Null
        $bag   = New-Object System.Collections.Generic.List[object]
        $piped = $false
    }

    process {
        if ($CloudPC) {
            $piped = $true
            foreach ($pc in $CloudPC) { $bag.Add($pc) }
        }
    }

    end {
        if (-not $piped) {
            $bag = [System.Collections.Generic.List[object]]@(
                Get-CloudPC -ProvisioningPolicyId $ProvisioningPolicyId -Type $Type
            )
        }

        $resolvedBag = New-Object System.Collections.Generic.List[object]
        $cloudPcLookup = $null
        foreach ($item in $bag) {
            if ($null -eq $item) {
                throw "CloudPC cannot be null, empty, or whitespace."
            }

            if ($item.PSObject.TypeNames -contains 'WindowsCloudPC.CloudPC') {
                $resolvedBag.Add($item)
                continue
            }

            if ($item -is [string]) {
                if ([string]::IsNullOrWhiteSpace($item)) {
                    throw "CloudPC cannot be null, empty, or whitespace."
                }

                if (-not $cloudPcLookup) {
                    $cloudPcLookup = @(Get-CloudPC -ProvisioningPolicyId $ProvisioningPolicyId -Type $Type)
                }

                $matches = @(
                    $cloudPcLookup | Where-Object {
                        $_.Id -eq $item -or
                        $_.Name -eq $item -or
                        $_.ManagedDeviceId -eq $item -or
                        $_.Raw.managedDeviceName -eq $item -or
                        $_.Raw.displayName -eq $item
                    }
                )

                if ($matches.Count -eq 0) {
                    throw "Could not find a Cloud PC matching '$item'. Pass a Cloud PC object from Get-CloudPC, or use an exact Cloud PC ID or name."
                }
                if ($matches.Count -gt 1) {
                    throw "Cloud PC identifier '$item' matched multiple Cloud PCs. Pass a Cloud PC object from Get-CloudPC or use a unique Cloud PC ID."
                }

                $resolvedBag.Add($matches[0])
                continue
            }

            throw "CloudPC must be a WindowsCloudPC.CloudPC object from Get-CloudPC, or a Cloud PC ID or name string."
        }

        foreach ($pc in $resolvedBag) {
            $managedDevice = if ($pc.ManagedDeviceId) { Get-CloudPCManagedDevice -ManagedDeviceId $pc.ManagedDeviceId } else { $null }
            if (-not $managedDevice) {
                Write-Warning "Could not find an Intune managedDevice record for Cloud PC '$($pc.Name)'. Disk space is unavailable."
            }

            $totalBytes = $managedDevice.totalStorageSpaceInBytes
            $freeBytes  = $managedDevice.freeStorageSpaceInBytes
            $usedBytes  = if ($null -ne $totalBytes -and $null -ne $freeBytes) { [int64]$totalBytes - [int64]$freeBytes } else { $null }

            $totalGb = if ($null -ne $totalBytes) { [math]::Round(([double]$totalBytes / 1GB), 2) } else { $null }
            $freeGb  = if ($null -ne $freeBytes)  { [math]::Round(([double]$freeBytes  / 1GB), 2) } else { $null }
            $usedGb  = if ($null -ne $usedBytes)  { [math]::Round(([double]$usedBytes  / 1GB), 2) } else { $null }

            $percentFree = if ($null -ne $totalBytes -and [double]$totalBytes -gt 0 -and $null -ne $freeBytes) {
                [math]::Round(([double]$freeBytes / [double]$totalBytes) * 100, 1)
            }
            else {
                $null
            }

            $percentUsed = if ($null -ne $percentFree) { [math]::Round(100 - $percentFree, 1) } else { $null }
            $lastSyncDateTime = if ($managedDevice.lastSyncDateTime) {
                ([datetime]$managedDevice.lastSyncDateTime).ToLocalTime()
            }
            else {
                $null
            }

            [pscustomobject]@{
                PSTypeName             = 'WindowsCloudPC.CloudPCDiskSpace'
                CloudPcName            = $pc.Name
                ManagedDeviceName      = if ($managedDevice.deviceName) { $managedDevice.deviceName } else { $pc.Raw.managedDeviceName }
                ProvisioningType       = $pc.ProvisioningType
                ProvisioningPolicyName = $pc.ProvisioningPolicyName
                AssignedUserUpn        = $pc.AssignedUserUpn
                TotalStorageGB         = $totalGb
                FreeStorageGB          = $freeGb
                UsedStorageGB          = $usedGb
                PercentFree            = $percentFree
                PercentUsed            = $percentUsed
                LastSyncDateTime       = $lastSyncDateTime
                CloudPcId              = $pc.Id
                ManagedDeviceId        = $pc.ManagedDeviceId
                RawManagedDevice       = $managedDevice
            }
        }
    }
}
