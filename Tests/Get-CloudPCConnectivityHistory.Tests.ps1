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
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
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

        $r = Get-CloudPCConnectivityHistory -CloudPcId 'cloud pc/id'

        $r.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.CloudPCConnectivityEvent'
        $r.CloudPcId | Should -Be 'cloud pc/id'
        $r.ActivityId | Should -Be 'activity-1'
        $r.EventDateTime | Should -BeOfType [datetime]
        Should -Invoke -ModuleName WindowsCloudPC Invoke-GraphPaged -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/cloud%20pc%2Fid/getCloudPcConnectivityHistory'
        }
    }

    It 'accepts Cloud PC objects from the pipeline' {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-GraphPaged -MockWith {
            @(
                @{
                    activityId    = 'activity-2'
                    eventDateTime = '2026-06-17T19:10:53Z'
                    eventType     = 'userConnection'
                    eventName     = 'Connection Finished'
                    eventResult   = 'success'
                    message       = ''
                }
            )
        }

        $pc = [pscustomobject]@{
            PSTypeName = 'WindowsCloudPC.CloudPC'
            Id         = 'cpc-1'
            Name       = 'CPC-ONE'
        }

        $r = $pc | Get-CloudPCConnectivityHistory

        $r.CloudPcId | Should -Be 'cpc-1'
        $r.CloudPcName | Should -Be 'CPC-ONE'
    }

    It 'returns null when Graph throws' {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { }
        Mock -ModuleName WindowsCloudPC Invoke-GraphPaged -MockWith { throw 'boom' }

        $r = Get-CloudPCConnectivityHistory -CloudPcId 'bad'

        $r | Should -BeNullOrEmpty
    }
}
