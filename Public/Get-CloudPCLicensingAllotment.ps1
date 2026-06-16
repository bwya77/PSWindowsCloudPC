function Get-CloudPCLicensingAllotment {
    <#
    .SYNOPSIS
        Returns Microsoft Graph cloud licensing allotments.

    .DESCRIPTION
        Calls the Microsoft Graph beta /admin/cloudLicensing/allotments endpoint
        and returns normalized WindowsCloudPC.LicensingAllotment objects.

        By default, the cmdlet lists every allotment. Pass -Id to retrieve a
        single allotment. Optional OData query parameters can be used to shape
        the Graph response for testing the beta endpoint.

    .PARAMETER Id
        Optional allotment ID. When provided, the cmdlet retrieves only that
        allotment.

    .PARAMETER Select
        Optional OData $select fields.

    .PARAMETER Expand
        Optional OData $expand expression.

    .PARAMETER Filter
        Optional OData $filter expression.

    .PARAMETER Top
        Optional OData $top value for list queries.

    .PARAMETER Apply
        Optional OData $apply expression for list queries.

    .EXAMPLE
        Get-CloudPCLicensingAllotment | Format-Table SkuPartNumber,AllottedUnits,ConsumedUnits,AvailableUnits

        Lists licensing allotments with capacity and consumption.

    .EXAMPLE
        Get-CloudPCLicensingAllotment -Id 'fde42873-30b6-436b-b361-21af5a6b84ae'

        Gets one licensing allotment by ID.

    .EXAMPLE
        Get-CloudPCLicensingAllotment -Select id,skuPartNumber,allottedUnits,consumedUnits -Expand 'waitingMembers($select=id,waitingSinceDateTime)'

        Lists licensing allotments with selected fields and expanded waiting members.
    #>
    [CmdletBinding()]
    [OutputType('WindowsCloudPC.LicensingAllotment')]
    param(
        [Parameter(Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('AllotmentId')]
        [string]$Id,

        [Alias('Property')]
        [string[]]$Select,

        [string]$Expand,

        [string]$Filter,

        [ValidateRange(1, 999)]
        [int]$Top,

        [string]$Apply
    )

    begin {
        Connect-CloudPC -AdditionalScopes 'CloudLicensing.Read' | Out-Null
    }

    process {
        $query = [System.Collections.Generic.List[string]]::new()

        if ($Select) {
            $query.Add('$select=' + [uri]::EscapeDataString(($Select -join ',')))
        }
        if ($Expand) {
            $query.Add('$expand=' + [uri]::EscapeDataString($Expand))
        }
        if ($Filter) {
            $query.Add('$filter=' + [uri]::EscapeDataString($Filter))
        }
        if ($PSBoundParameters.ContainsKey('Top')) {
            $query.Add('$top=' + $Top)
        }
        if ($Apply) {
            $query.Add('$apply=' + [uri]::EscapeDataString($Apply))
        }

        if ($Id) {
            $escapedId = [uri]::EscapeDataString($Id)
            $uri = 'https://graph.microsoft.com/beta/admin/cloudLicensing/allotments/' + $escapedId
            if ($query.Count -gt 0) {
                $uri += '?' + ($query -join '&')
            }

            try {
                $response = Invoke-MgGraphRequest -Method GET -Uri $uri
                $allotments = @(
                    if ($response.value -and $response.value.id) {
                        $response.value
                    }
                    else {
                        $response
                    }
                )
            }
            catch {
                Write-Error "Cloud licensing allotment '$Id' not found: $($_.Exception.Message)"
                return
            }
        }
        else {
            $uri = 'https://graph.microsoft.com/beta/admin/cloudLicensing/allotments'
            if ($query.Count -gt 0) {
                $uri += '?' + ($query -join '&')
            }

            $allotments = @(Invoke-GraphPaged -Uri $uri)
        }

        foreach ($allotment in $allotments) {
            $services = @($allotment.services)
            $subscriptions = @($allotment.subscriptions)
            $waitingMembers = @($allotment.waitingMembers)
            $allottedUnits = $allotment.allottedUnits
            $consumedUnits = $allotment.consumedUnits
            $availableUnits = if ($null -ne $allottedUnits -and $null -ne $consumedUnits) {
                $allottedUnits - $consumedUnits
            }
            else {
                $null
            }

            [pscustomobject]@{
                PSTypeName       = 'WindowsCloudPC.LicensingAllotment'
                Id               = $allotment.id
                SkuId            = $allotment.skuId
                SkuPartNumber    = $allotment.skuPartNumber
                AllottedUnits    = $allottedUnits
                ConsumedUnits    = $consumedUnits
                AvailableUnits   = $availableUnits
                AssignableTo     = $allotment.assignableTo
                ServiceCount     = $services.Count
                ServicePlanNames = @($services | ForEach-Object { $_.planName })
                Services         = $services
                SubscriptionCount = $subscriptions.Count
                SubscriptionIds  = @($subscriptions | ForEach-Object { $_.subscriptionId })
                Subscriptions    = $subscriptions
                WaitingMemberCount = $waitingMembers.Count
                WaitingMembers   = $waitingMembers
                Raw              = $allotment
            }
        }
    }

    end { }
}

