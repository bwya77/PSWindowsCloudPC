function Get-CloudPCSupportedRegion {
    <#
    .SYNOPSIS
        Returns Windows 365 Cloud PC supported regions.

    .DESCRIPTION
        Calls the Microsoft Graph beta /deviceManagement/virtualEndpoint/supportedRegions
        endpoint and returns normalized WindowsCloudPC.SupportedRegion objects.

        The cmdlet requests the common region metadata with $select so Graph includes
        non-default fields such as regionGroup and geographicLocationType.

    .PARAMETER RegionStatus
        Optional filter for region status. Common values include available and restricted.

    .PARAMETER SupportedSolution
        Optional filter for supported solution. Defaults to windows365.

    .PARAMETER RegionGroup
        Optional filter for region group, such as usEast, usWest, europeUnion, or australia.

    .PARAMETER GeographicLocationType
        Optional filter for geographic location type, such as usEast, europe, or asia.

    .EXAMPLE
        Get-CloudPCSupportedRegion | Format-Table DisplayName,RegionStatus,RegionGroup

        Lists supported Windows 365 Cloud PC regions.

    .EXAMPLE
        Get-CloudPCSupportedRegion -RegionStatus available -RegionGroup usEast

        Lists available Windows 365 regions in the usEast region group.

    .EXAMPLE
        Get-CloudPCSupportedRegion -GeographicLocationType europe |
            Sort-Object DisplayName

        Lists supported Windows 365 regions in the Europe geographic location.
    #>
    [CmdletBinding()]
    [OutputType('WindowsCloudPC.SupportedRegion')]
    param(
        [ValidateSet('available','restricted')]
        [string]$RegionStatus,

        [string]$SupportedSolution = 'windows365',

        [string]$RegionGroup,

        [string]$GeographicLocationType
    )

    begin {
        Connect-CloudPC | Out-Null
    }

    process {
        $select = @(
            'id',
            'displayName',
            'regionStatus',
            'supportedSolution',
            'regionGroup',
            'geographicLocationType'
        ) -join ','

        $uri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/supportedRegions' +
               '?$select=' + [uri]::EscapeDataString($select)

        Invoke-GraphPaged -Uri $uri | ForEach-Object {
            $region = $_

            if ($RegionStatus -and $region.regionStatus -ne $RegionStatus) { return }
            if ($SupportedSolution -and $region.supportedSolution -ne $SupportedSolution) { return }
            if ($RegionGroup -and $region.regionGroup -ne $RegionGroup) { return }
            if ($GeographicLocationType -and $region.geographicLocationType -ne $GeographicLocationType) { return }

            [pscustomobject]@{
                PSTypeName              = 'WindowsCloudPC.SupportedRegion'
                Id                      = $region.id
                DisplayName             = $region.displayName
                RegionStatus            = $region.regionStatus
                SupportedSolution       = $region.supportedSolution
                RegionGroup             = $region.regionGroup
                GeographicLocationType  = $region.geographicLocationType
                Raw                     = $region
            }
        }
    }

    end { }
}

