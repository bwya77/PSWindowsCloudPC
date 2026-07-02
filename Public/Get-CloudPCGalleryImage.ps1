function Get-CloudPCGalleryImage {
    <#
    .SYNOPSIS
        Returns Windows 365 Cloud PC gallery images.

    .DESCRIPTION
        Calls the Microsoft Graph beta
        https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/galleryImages
        endpoint and returns Microsoft gallery images available for Cloud PC provisioning.

    .PARAMETER Id
        Optional exact gallery image ID filter.

    .PARAMETER DisplayName
        Optional exact display name filter. Alias: Name.

    .PARAMETER Status
        Optional gallery image status filter.

    .EXAMPLE
        Get-CloudPCGalleryImage | Format-Table DisplayName,Status,RecommendedSku,SizeGB

    .EXAMPLE
        Get-CloudPCGalleryImage -DisplayName 'Windows 11 Enterprise 24H2'

    .EXAMPLE
        Get-CloudPCGalleryImage -Status supported
    #>
    [CmdletBinding()]
    [OutputType('WindowsCloudPC.GalleryImage')]
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
            'offerDisplayName',
            'skuDisplayName',
            'publisher',
            'publisherName',
            'offer',
            'offerName',
            'sku',
            'skuName',
            'recommendedSku',
            'status',
            'sizeInGB',
            'startDate',
            'endDate',
            'expirationDate',
            'osVersionNumber'
        ) -join ','

        $uri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/galleryImages' +
               '?$select=' + [uri]::EscapeDataString($select)

        Invoke-GraphPaged -Uri $uri | ForEach-Object {
            $image = $_

            if ($Id -and $image.id -ne $Id) { return }
            if ($DisplayName -and $image.displayName -ne $DisplayName) { return }
            if ($Status -and $image.status -ne $Status) { return }

            [pscustomobject]@{
                PSTypeName       = 'WindowsCloudPC.GalleryImage'
                Id               = $image.id
                DisplayName      = $image.displayName
                OfferDisplayName = $image.offerDisplayName
                SkuDisplayName   = $image.skuDisplayName
                Publisher        = $image.publisher
                PublisherName    = $image.publisherName
                Offer            = $image.offer
                OfferName        = $image.offerName
                Sku              = $image.sku
                SkuName          = $image.skuName
                RecommendedSku   = $image.recommendedSku
                Status           = $image.status
                SizeGB           = $image.sizeInGB
                StartDate        = if ($image.startDate) { [datetime]$image.startDate } else { $null }
                EndDate          = if ($image.endDate) { [datetime]$image.endDate } else { $null }
                ExpirationDate   = if ($image.expirationDate) { [datetime]$image.expirationDate } else { $null }
                OsVersionNumber  = $image.osVersionNumber
                Raw              = $image
            }
        }
    }
}
