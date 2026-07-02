function Get-CloudPCCustomImage {
    <#
    .SYNOPSIS
        Returns Windows 365 Cloud PC custom device images.

    .DESCRIPTION
        Calls the Microsoft Graph beta
        https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/deviceImages
        endpoint and returns custom OS images uploaded for Cloud PC provisioning.

    .PARAMETER Id
        Optional exact custom image ID filter.

    .PARAMETER DisplayName
        Optional exact display name filter. Alias: Name.

    .PARAMETER Status
        Optional image status filter.

    .EXAMPLE
        Get-CloudPCCustomImage | Format-Table DisplayName,Status,OperatingSystem,OsBuildNumber

    .EXAMPLE
        Get-CloudPCCustomImage -DisplayName 'Win11-Corp-Image'

    .EXAMPLE
        Get-CloudPCCustomImage -Status ready
    #>
    [CmdletBinding()]
    [OutputType('WindowsCloudPC.CustomImage')]
    param(
        [string]$Id,

        [Alias('Name')]
        [string]$DisplayName,

        [string]$Status
    )

    begin {
        Connect-CloudPC | Out-Null
    }

    process {
        $select = @(
            'id',
            'displayName',
            'operatingSystem',
            'osBuildNumber',
            'version',
            'status',
            'expirationDate',
            'osStatus',
            'sourceImageResourceId',
            'lastModifiedDateTime',
            'statusDetails',
            'errorCode',
            'osVersionNumber',
            'sizeInGB'
        ) -join ','

        $uri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/deviceImages' +
               '?$select=' + [uri]::EscapeDataString($select)

        Invoke-GraphPaged -Uri $uri | ForEach-Object {
            $image = $_

            if ($Id -and $image.id -ne $Id) { return }
            if ($DisplayName -and $image.displayName -ne $DisplayName) { return }
            if ($Status -and $image.status -ne $Status) { return }

            [pscustomobject]@{
                PSTypeName            = 'WindowsCloudPC.CustomImage'
                Id                    = $image.id
                DisplayName           = $image.displayName
                OperatingSystem       = $image.operatingSystem
                OsBuildNumber         = $image.osBuildNumber
                OsVersionNumber       = $image.osVersionNumber
                Version               = $image.version
                Status                = $image.status
                StatusDetails         = $image.statusDetails
                ErrorCode             = $image.errorCode
                OsStatus              = $image.osStatus
                ExpirationDate        = if ($image.expirationDate) { [datetime]$image.expirationDate } else { $null }
                LastModifiedDateTime  = if ($image.lastModifiedDateTime) { ([datetime]$image.lastModifiedDateTime).ToLocalTime() } else { $null }
                SizeGB                = $image.sizeInGB
                SourceImageResourceId = $image.sourceImageResourceId
                Raw                   = $image
            }
        }
    }
}
