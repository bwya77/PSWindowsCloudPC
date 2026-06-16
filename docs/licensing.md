---
id: licensing
title: Licensing
description: Read Microsoft Graph cloud licensing allotments.
---

# Licensing

`Get-CloudPCLicensingAllotment` reads Microsoft Graph cloud licensing allotments. Use it to inspect SKU capacity, consumed units, available units, services, and subscription metadata.

## List allotments

```powershell
Get-CloudPCLicensingAllotment |
    Format-Table SkuPartNumber,AllottedUnits,ConsumedUnits,AvailableUnits
```

## Get one allotment

```powershell
Get-CloudPCLicensingAllotment -Id '<allotment-id>' |
    Format-List Id,SkuPartNumber,AllottedUnits,ConsumedUnits,AvailableUnits
```

## Find constrained SKUs

```powershell
Get-CloudPCLicensingAllotment |
    Where-Object AvailableUnits -lt 10 |
    Sort-Object AvailableUnits |
    Select-Object SkuPartNumber,AllottedUnits,ConsumedUnits,AvailableUnits
```

## Include services and subscriptions

```powershell
Get-CloudPCLicensingAllotment -Expand services,subscriptions |
    Select-Object SkuPartNumber,Services,Subscriptions
```

## Permissions

This command uses the delegated `CloudLicensing.Read` Graph scope. Some tenants may require administrator consent before the scope can be used.

