BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CloudPCLicensingAllotment' {

    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-GraphPaged {
            @(
                [pscustomobject]@{
                    id             = 'allotment-1'
                    allottedUnits  = 250
                    assignableTo   = 'user,group'
                    consumedUnits  = 224
                    services       = @(
                        [pscustomobject]@{
                            assignableTo = 'user,group'
                            planId       = '9aaf7827-d63c-4b61-89c3-182f06f82e5c'
                            planName     = 'EXCHANGE_S_STANDARD'
                        },
                        [pscustomobject]@{
                            assignableTo = 'none'
                            planId       = '6f23d6a9-adbf-481c-8538-b4c095654487'
                            planName     = 'M365_LIGHTHOUSE_CUSTOMER_PLAN1'
                        }
                    )
                    skuId          = '4b9405b0-7788-4568-add1-99614e613b69'
                    skuPartNumber  = 'EXCHANGESTANDARD'
                }
            )
        }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest {
            [pscustomobject]@{
                value = [pscustomobject]@{
                    id             = 'allotment-2'
                    allottedUnits  = 100
                    assignableTo   = 'user,group'
                    consumedUnits  = 84
                    services       = @(
                        [pscustomobject]@{
                            assignableTo = 'user,group'
                            planId       = 'f4f2f6de-6830-442b-a433-e92249faebe2'
                            planName     = 'TeamsEss'
                        }
                    )
                    skuId          = 'f245ecc8-75af-4f8e-b61f-27d8114de5f3'
                    skuPartNumber  = 'Teams_Ess'
                    subscriptions  = @(
                        [pscustomobject]@{
                            subscriptionId    = 'f196adf8-75fa-8e4f-c61d-42d8114de4f4'
                            nextLifecycleDate = '2025-09-30T00:00:00.000Z'
                            startDate         = '2025-07-18T00:00:00.000Z'
                            state             = 'active'
                            tags              = 'none'
                        }
                    )
                }
            }
        }
    }

    It 'requests CloudLicensing.Read when connecting' {
        Get-CloudPCLicensingAllotment | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Connect-CloudPC -Times 1 -Exactly -ParameterFilter {
            $AdditionalScopes -contains 'CloudLicensing.Read'
        }
    }

    It 'queries the admin cloud licensing allotments endpoint' {
        Get-CloudPCLicensingAllotment | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-GraphPaged -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://graph.microsoft.com/beta/admin/cloudLicensing/allotments'
        }
    }

    It 'adds supported OData query parameters for list queries' {
        Get-CloudPCLicensingAllotment `
            -Select id,skuPartNumber,allottedUnits,consumedUnits `
            -Expand 'waitingMembers($select=id,waitingSinceDateTime)' `
            -Filter "skuPartNumber eq 'EXCHANGESTANDARD'" `
            -Top 5 `
            -Apply 'groupby((skuId,skuPartNumber), aggregate(allottedUnits with sum as totalAllottedUnits))' |
            Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-GraphPaged -Times 1 -Exactly -ParameterFilter {
            $Uri -like 'https://graph.microsoft.com/beta/admin/cloudLicensing/allotments?*' -and
            $Uri -like '*$select=id%2CskuPartNumber%2CallottedUnits%2CconsumedUnits*' -and
            $Uri -like '*$expand=waitingMembers%28%24select%3Did%2CwaitingSinceDateTime%29*' -and
            $Uri -like '*$filter=skuPartNumber%20eq%20%27EXCHANGESTANDARD%27*' -and
            $Uri -like '*$top=5*' -and
            $Uri -like '*$apply=groupby%28%28skuId%2CskuPartNumber%29%2C%20aggregate%28allottedUnits%20with%20sum%20as%20totalAllottedUnits%29%29*'
        }
    }

    It 'emits WindowsCloudPC.LicensingAllotment objects with flattened capacity and services' {
        $allotments = Get-CloudPCLicensingAllotment

        $allotments | Should -HaveCount 1
        $allotments[0].PSObject.TypeNames | Should -Contain 'WindowsCloudPC.LicensingAllotment'
        $allotments[0].Id | Should -Be 'allotment-1'
        $allotments[0].SkuPartNumber | Should -Be 'EXCHANGESTANDARD'
        $allotments[0].AllottedUnits | Should -Be 250
        $allotments[0].ConsumedUnits | Should -Be 224
        $allotments[0].AvailableUnits | Should -Be 26
        $allotments[0].ServiceCount | Should -Be 2
        $allotments[0].ServicePlanNames | Should -Be @('EXCHANGE_S_STANDARD','M365_LIGHTHOUSE_CUSTOMER_PLAN1')
    }

    It 'gets a single allotment by Id and unwraps Graph value responses' {
        $allotment = Get-CloudPCLicensingAllotment -Id 'allotment-2'

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and
            $Uri -eq 'https://graph.microsoft.com/beta/admin/cloudLicensing/allotments/allotment-2'
        }
        $allotment.Id | Should -Be 'allotment-2'
        $allotment.SkuPartNumber | Should -Be 'Teams_Ess'
        $allotment.SubscriptionCount | Should -Be 1
        $allotment.SubscriptionIds | Should -Be @('f196adf8-75fa-8e4f-c61d-42d8114de4f4')
    }

    It 'preserves the raw Graph allotment on Raw' {
        $allotment = Get-CloudPCLicensingAllotment | Select-Object -First 1

        $allotment.Raw | Should -Not -BeNullOrEmpty
        $allotment.Raw.skuPartNumber | Should -Be 'EXCHANGESTANDARD'
    }

    It 'writes an error when a single allotment lookup fails' {
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { throw 'not found' }

        $errors = @()
        $result = Get-CloudPCLicensingAllotment -Id 'missing' -ErrorVariable errors -ErrorAction SilentlyContinue

        $result | Should -BeNullOrEmpty
        ($errors | ForEach-Object { $_.ToString() }) -join "`n" | Should -Match "Cloud licensing allotment 'missing' not found"
    }
}

