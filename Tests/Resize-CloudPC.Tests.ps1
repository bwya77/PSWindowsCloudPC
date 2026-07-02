BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Resize-CloudPC' {

    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { }
    }

    It 'POSTs to the v1.0 resize endpoint for the given Id' {
        Resize-CloudPC -Id 'cpc-1' -TargetServicePlanId 'plan-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'POST' -and $Uri -eq 'https://graph.microsoft.com/v1.0/deviceManagement/virtualEndpoint/cloudPCs/cpc-1/resize'
        }
    }

    It 'requests CloudPC.ReadWrite.All when connecting' {
        Resize-CloudPC -Id 'cpc-1' -TargetServicePlanId 'plan-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Connect-CloudPC -Times 1 -Exactly -ParameterFilter {
            $AdditionalScopes -contains 'CloudPC.ReadWrite.All'
        }
    }

    It 'sends targetServicePlanId in a JSON body' {
        Resize-CloudPC -Id 'cpc-1' -TargetServicePlanId 'plan-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $ContentType -eq 'application/json' -and
            (($Body | ConvertFrom-Json).targetServicePlanId -eq 'plan-1')
        }
    }

    It 'accepts WindowsCloudPC.CloudPC objects from the pipeline' {
        $cpc = [pscustomobject]@{
            PSTypeName = 'WindowsCloudPC.CloudPC'
            Id         = 'cpc-from-pipeline'
            Name       = 'CPC-PIPE-01'
        }

        $cpc | Resize-CloudPC -TargetServicePlanId 'plan-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*cloudPCs/cpc-from-pipeline/resize'
        }
    }

    It 'resizes every Cloud PC piped in' {
        $cpcs = @(
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-a'; Name = 'A' }
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-b'; Name = 'B' }
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-c'; Name = 'C' }
        )

        $cpcs | Resize-CloudPC -TargetServicePlanId 'plan-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 3 -Exactly
    }

    It 'creates a beta cloudPcBulkResize bulk action when -UseMaintenanceWindow is specified' {
        Resize-CloudPC -Id 'cpc-1' -TargetServicePlanId 'plan-1' -UseMaintenanceWindow -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $parsed = $Body | ConvertFrom-Json
            $Method -eq 'POST' -and
            $Uri -eq 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/bulkActions' -and
            $ContentType -eq 'application/json' -and
            $parsed.'@odata.type' -eq '#microsoft.graph.cloudPcBulkResize' -and
            $parsed.displayName -eq 'Resize Cloud PCs to plan-1' -and
            $parsed.targetServicePlanId -eq 'plan-1' -and
            $parsed.scheduledDuringMaintenanceWindow -eq $true -and
            @($parsed.cloudPcIds).Count -eq 1 -and
            @($parsed.cloudPcIds)[0] -eq 'cpc-1'
        }
    }

    It 'submits piped Cloud PCs as one maintenance-window bulk resize action' {
        $cpcs = @(
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-a'; Name = 'A' }
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-b'; Name = 'B' }
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-c'; Name = 'C' }
        )

        $cpcs | Resize-CloudPC -TargetServicePlanId 'plan-1' -UseMaintenanceWindow -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $parsed = $Body | ConvertFrom-Json
            $Uri -eq 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/bulkActions' -and
            $parsed.'@odata.type' -eq '#microsoft.graph.cloudPcBulkResize' -and
            @($parsed.cloudPcIds).Count -eq 3 -and
            @($parsed.cloudPcIds) -contains 'cpc-a' -and
            @($parsed.cloudPcIds) -contains 'cpc-b' -and
            @($parsed.cloudPcIds) -contains 'cpc-c' -and
            $parsed.scheduledDuringMaintenanceWindow -eq $true
        }
    }

    It 'emits ResizeResult rows with bulk action metadata when -UseMaintenanceWindow and -PassThru are specified' {
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest {
            [pscustomobject]@{
                id                               = 'bulk-action-1'
                status                           = 'pending'
                scheduledDuringMaintenanceWindow = $true
            }
        }

        $result = Resize-CloudPC -Id 'cpc-1' -TargetServicePlanId 'plan-1' -UseMaintenanceWindow -PassThru -Force -Confirm:$false

        $result | Should -Not -BeNullOrEmpty
        $result.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.ResizeResult'
        $result.CloudPcId | Should -Be 'cpc-1'
        $result.Status | Should -Be 'pending'
        $result.UseMaintenanceWindow | Should -BeTrue
        $result.ScheduledDuringMaintenanceWindow | Should -BeTrue
        $result.BulkActionId | Should -Be 'bulk-action-1'
        $result.RawBulkAction.id | Should -Be 'bulk-action-1'
    }

    It 'accepts an exact Cloud PC name for the CloudPC parameter' {
        Mock -ModuleName WindowsCloudPC Get-CloudPC {
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-from-name'; Name = 'CPC-BRAD-01' }
        }

        Resize-CloudPC -CloudPC 'CPC-BRAD-01' -TargetServicePlanId 'plan-1' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*cloudPCs/cpc-from-name/resize'
        }
    }

    It 'resolves a target service plan by exact display name' {
        Mock -ModuleName WindowsCloudPC Get-CloudPCServicePlan {
            [pscustomobject]@{
                PSTypeName  = 'WindowsCloudPC.ServicePlan'
                Id          = 'plan-from-name'
                DisplayName = 'Cloud PC Enterprise 4vCPU/16GB/128GB'
            }
        }

        Resize-CloudPC -Id 'cpc-1' -TargetServicePlanName 'Cloud PC Enterprise 4vCPU/16GB/128GB' -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            (($Body | ConvertFrom-Json).targetServicePlanId -eq 'plan-from-name')
        }
    }

    It 'accepts a WindowsCloudPC.ServicePlan target object' {
        $plan = [pscustomobject]@{
            PSTypeName  = 'WindowsCloudPC.ServicePlan'
            Id          = 'plan-from-object'
            DisplayName = 'Cloud PC Enterprise 8vCPU/32GB/256GB'
        }

        Resize-CloudPC -Id 'cpc-1' -TargetServicePlan $plan -Force -Confirm:$false

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            (($Body | ConvertFrom-Json).targetServicePlanId -eq 'plan-from-object')
        }
    }

    It 'does not call Graph when a Cloud PC string cannot be resolved' {
        Mock -ModuleName WindowsCloudPC Get-CloudPC { @() }

        Resize-CloudPC -CloudPC 'CPC-MISSING' -TargetServicePlanId 'plan-1' -Force -Confirm:$false -ErrorAction SilentlyContinue

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
    }

    It 'requires a target service plan' {
        { Resize-CloudPC -Id 'cpc-1' -Force -Confirm:$false } | Should -Throw '*Supply -TargetServicePlanId, -TargetServicePlanName, or -TargetServicePlan*'
    }

    It 'is silent by default on success' {
        $result = Resize-CloudPC -Id 'cpc-1' -TargetServicePlanId 'plan-1' -Force -Confirm:$false
        $result | Should -BeNullOrEmpty
    }

    It 'emits a ResizeResult object with -PassThru' {
        $result = Resize-CloudPC -Id 'cpc-1' -TargetServicePlanId 'plan-1' -PassThru -Force -Confirm:$false

        $result | Should -Not -BeNullOrEmpty
        $result.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.ResizeResult'
        $result.CloudPcId | Should -Be 'cpc-1'
        $result.TargetServicePlanId | Should -Be 'plan-1'
        $result.Status | Should -Be 'Accepted'
        $result.ErrorMessage | Should -BeNullOrEmpty
    }

    It 'reports Failed status with -PassThru when Graph throws' {
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { throw 'Graph 500' }

        $result = Resize-CloudPC -Id 'cpc-broken' -TargetServicePlanId 'plan-1' -PassThru -Force -Confirm:$false -ErrorAction SilentlyContinue

        $result.Status | Should -Be 'Failed'
        $result.ErrorMessage | Should -Match 'Graph 500'
    }

    It 'includes Graph error details when the service returns a response body' {
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest {
            $exception = [System.Exception]::new('Response status code does not indicate success: Conflict (Conflict).')
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                $exception,
                'Conflict',
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $null
            )
            $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Conflict","message":"Resize is not allowed for the current Cloud PC state."}}')
            Write-Error -ErrorRecord $errorRecord -ErrorAction Stop
        }

        $result = Resize-CloudPC -Id 'cpc-broken' -TargetServicePlanId 'plan-1' -PassThru -Force -Confirm:$false -ErrorAction SilentlyContinue

        $result.Status | Should -Be 'Failed'
        $result.ErrorMessage | Should -Match 'Resize is not allowed for the current Cloud PC state'
    }

    It 'does not call Graph when -WhatIf is passed' {
        Resize-CloudPC -Id 'cpc-1' -TargetServicePlanId 'plan-1' -WhatIf

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
    }

    It 'emits a WhatIf result when -WhatIf and -PassThru are passed' {
        $result = Resize-CloudPC -Id 'cpc-1' -TargetServicePlanId 'plan-1' -WhatIf -PassThru

        $result.Status | Should -Be 'WhatIf'
        $result.RequestedAt | Should -BeNullOrEmpty
    }

    It 'does not submit a maintenance-window bulk resize when -WhatIf is passed' {
        Resize-CloudPC -Id 'cpc-1' -TargetServicePlanId 'plan-1' -UseMaintenanceWindow -WhatIf

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 0 -Exactly
    }
}
