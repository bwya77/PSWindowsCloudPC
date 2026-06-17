BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CloudPCConnectivityHistory' {

    It 'calls the Cloud PC connectivity history endpoint and normalizes events' {
        Mock -ModuleName WindowsCloudPC Invoke-GraphPaged -MockWith {
            @(
                @{
                    activityId    = 'activity-1'
                    eventDateTime = '2026-06-17T18:31:45Z'
                    eventType     = 'userConnection'
                    eventName     = 'Connection Started'
                    eventResult   = 'success'
                    message       = ''
                }
            )
        }

        $r = & (Get-Module WindowsCloudPC) { Get-CloudPCConnectivityHistory -CloudPcId 'cloud pc/id' }

        $r.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.CloudPCConnectivityEvent'
        $r.ActivityId | Should -Be 'activity-1'
        $r.EventDateTime | Should -BeOfType [datetime]
        Should -Invoke -ModuleName WindowsCloudPC Invoke-GraphPaged -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/cloud%20pc%2Fid/getCloudPcConnectivityHistory'
        }
    }

    It 'returns null when Graph throws' {
        Mock -ModuleName WindowsCloudPC Invoke-GraphPaged -MockWith { throw 'boom' }

        $r = & (Get-Module WindowsCloudPC) { Get-CloudPCConnectivityHistory -CloudPcId 'bad' }

        $r | Should -BeNullOrEmpty
    }
}
