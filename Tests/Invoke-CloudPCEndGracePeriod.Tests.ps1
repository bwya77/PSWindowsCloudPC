BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-CloudPCEndGracePeriod' {
    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { }
        Mock -ModuleName WindowsCloudPC Start-Sleep { }
        Mock -ModuleName WindowsCloudPC Get-CloudPC {
            @(
                [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-grace-1'; Name = 'CPC-GRACE-01'; ProvisioningStatus = 'inGracePeriod' }
                [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-grace-2'; Name = 'CPC-GRACE-02'; ProvisioningStatus = 'inGracePeriod' }
            )
        }
    }

    It 'requests CloudPC.ReadWrite.All when connecting' {
        Invoke-CloudPCEndGracePeriod -Id 'cpc-grace-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Connect-CloudPC -Times 1 -Exactly -ParameterFilter {
            $AdditionalScopes -contains 'CloudPC.ReadWrite.All'
        }
    }

    It 'POSTs to the beta endGracePeriod endpoint' {
        Invoke-CloudPCEndGracePeriod -Id 'cpc-grace-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'POST' -and
            $Uri -eq 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/cpc-grace-1/endGracePeriod'
        }
    }

    It 'uses Get-CloudPC -ProvisioningStatus inGracePeriod for All mode' {
        Invoke-CloudPCEndGracePeriod -All -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Get-CloudPC -Times 1 -Exactly -ParameterFilter {
            $ProvisioningStatus -eq 'inGracePeriod'
        }
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 2 -Exactly
    }

    It 'does not call Graph with WhatIf' {
        Invoke-CloudPCEndGracePeriod -Id 'cpc-grace-1' -WhatIf

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
    }

    It 'emits a result with PassThru' {
        $result = Invoke-CloudPCEndGracePeriod -Id 'cpc-grace-1' -Force -Confirm:$false -PassThru

        $result.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.EndGracePeriodResult'
        $result.CloudPcId | Should -Be 'cpc-grace-1'
        $result.Status | Should -Be 'Accepted'
        $result.ExpectedStateLag | Should -Be '5-10 minutes'
        $result.VerificationCommand | Should -Match 'Get-CloudPC -ProvisioningStatus inGracePeriod,deprovisioning'
        $result.WaitRequested | Should -BeFalse
    }

    It 'waits until the Cloud PC leaves inGracePeriod when Wait is supplied' {
        $script:WaitCallCount = 0
        Mock -ModuleName WindowsCloudPC Get-CloudPC {
            $script:WaitCallCount++
            if ($script:WaitCallCount -eq 1) {
                [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-grace-1'; Name = 'CPC-GRACE-01'; ProvisioningStatus = 'inGracePeriod' }
            }
            else {
                [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-grace-1'; Name = 'CPC-GRACE-01'; ProvisioningStatus = 'deprovisioning' }
            }
        } -ParameterFilter { $Id -eq 'cpc-grace-1' }

        $result = Invoke-CloudPCEndGracePeriod -Id 'cpc-grace-1' -Force -Confirm:$false -PassThru -Wait -PollIntervalSeconds 5 -TimeoutSeconds 30

        $result.Status | Should -Be 'Completed'
        $result.WaitRequested | Should -BeTrue
        $result.WaitTimedOut | Should -BeFalse
        $result.LastObservedProvisioningStatus | Should -Be 'deprovisioning'
        $result.CompletedAt | Should -BeOfType [datetime]
    }
}
