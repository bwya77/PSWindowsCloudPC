BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CloudPCLaunchDetail' {

    BeforeEach {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC {
            [pscustomobject]@{
                Account = 'signedin@contoso.com'
            }
        }
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest {
            @{
                cloudPcId                                     = 'cpc-1'
                cloudPcLaunchUrl                              = 'https://rdweb.example.test/launch/cpc-1'
                windows365SwitchCompatible                    = $false
                windows365SwitchCompatibilityFailureReasonType = 'osVersionNotSupported'
            }
        }
    }

    It 'queries the /me launch detail endpoint by default' {
        Get-CloudPCLaunchDetail -Id 'cpc-1' | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and $Uri -like 'https://graph.microsoft.com/v1.0/me/cloudPCs/cpc-1/retrieveCloudPcLaunchDetail'
        }
    }

    It 'queries the /users launch detail endpoint when UserId is provided' {
        Get-CloudPCLaunchDetail -Id 'cpc-1' -UserId 'user@contoso.com' | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and $Uri -like 'https://graph.microsoft.com/v1.0/users/user%40contoso.com/cloudPCs/cpc-1/retrieveCloudPcLaunchDetail'
        }
    }

    It 'emits a WindowsCloudPC.CloudPCLaunchDetail object' {
        $row = Get-CloudPCLaunchDetail -Id 'cpc-1'

        $row.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.CloudPCLaunchDetail'
        $row.CloudPcId | Should -Be 'cpc-1'
        $row.CloudPcLaunchUrl | Should -Be 'https://rdweb.example.test/launch/cpc-1'
        $row.WindowsAppLaunchUri | Should -Be 'ms-cloudpc:connect?cpcid=cpc-1&username=signedin%40contoso.com&environment=PROD&source=IWP&rdlaunchurl=https%3A%2F%2Frdweb.example.test%2Flaunch%2Fcpc-1'
        $row.Windows365SwitchCompatible | Should -BeFalse
        $row.Windows365SwitchCompatibilityFailureReasonType | Should -Be 'osVersionNotSupported'
        $row.LaunchDetailStatus | Should -Be 'Available'
        $row.ErrorMessage | Should -BeNullOrEmpty
    }

    It 'builds a Windows App launch URI when UserId is provided' {
        $row = Get-CloudPCLaunchDetail -Id 'cpc-1' -UserId 'user@contoso.com'

        $row.WindowsAppLaunchUri | Should -Be 'ms-cloudpc:connect?cpcid=cpc-1&username=user%40contoso.com&environment=PROD&source=IWP&rdlaunchurl=https%3A%2F%2Frdweb.example.test%2Flaunch%2Fcpc-1'
    }

    It 'accepts WindowsCloudPC.CloudPC objects from the pipeline' {
        $cpc = [pscustomobject]@{
            PSTypeName      = 'WindowsCloudPC.CloudPC'
            Id              = 'cpc-from-pipeline'
            Name            = 'CPC-PIPE-01'
            AssignedUserUpn = 'pipe@contoso.com'
        }

        $row = $cpc | Get-CloudPCLaunchDetail

        $row.CloudPcName | Should -Be 'CPC-PIPE-01'
        $row.UserId | Should -Be 'pipe@contoso.com'
        $row.WindowsAppLaunchUri | Should -Be 'ms-cloudpc:connect?cpcid=cpc-1&username=pipe%40contoso.com&environment=PROD&source=IWP&rdlaunchurl=https%3A%2F%2Frdweb.example.test%2Flaunch%2Fcpc-1'
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like 'https://graph.microsoft.com/v1.0/users/pipe%40contoso.com/cloudPCs/cpc-from-pipeline/retrieveCloudPcLaunchDetail'
        }
    }

    It 'uses /me and the signed-in account for piped Cloud PCs with no assigned user' {
        $cpc = [pscustomobject]@{
            PSTypeName = 'WindowsCloudPC.CloudPC'
            Id         = 'cpc-from-pipeline'
            Name       = 'CPC-PIPE-01'
        }

        $row = $cpc | Get-CloudPCLaunchDetail

        $row.UserId | Should -Be 'me'
        $row.WindowsAppLaunchUri | Should -Be 'ms-cloudpc:connect?cpcid=cpc-1&username=signedin%40contoso.com&environment=PROD&source=IWP&rdlaunchurl=https%3A%2F%2Frdweb.example.test%2Flaunch%2Fcpc-1'
        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like 'https://graph.microsoft.com/v1.0/me/cloudPCs/cpc-from-pipeline/retrieveCloudPcLaunchDetail'
        }
    }

    It 'leaves Windows App launch URI empty when no username is available' {
        Mock -ModuleName WindowsCloudPC Connect-CloudPC { [pscustomobject]@{ Account = $null } }

        $row = Get-CloudPCLaunchDetail -Id 'cpc-1'

        $row.UserId | Should -Be 'me'
        $row.WindowsAppLaunchUri | Should -BeNullOrEmpty
    }

    It 'queries each Cloud PC piped in' {
        $cpcs = @(
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-a'; Name = 'A' }
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-b'; Name = 'B' }
            [pscustomobject]@{ PSTypeName = 'WindowsCloudPC.CloudPC'; Id = 'cpc-c'; Name = 'C' }
        )

        $cpcs | Get-CloudPCLaunchDetail | Out-Null

        Should -Invoke -ModuleName WindowsCloudPC Invoke-MgGraphRequest -Times 3 -Exactly
    }

    It 'writes a non-terminating error when Graph throws' {
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest { throw 'Graph 500' }

        $errors = $null
        Get-CloudPCLaunchDetail -Id 'cpc-broken' -ErrorVariable errors -ErrorAction SilentlyContinue | Out-Null

        $errors | Should -Not -BeNullOrEmpty
        $errors[0].Exception.Message | Should -Match 'Graph 500'
    }

    It 'emits an unavailable row instead of an error when launch detail is not found' {
        Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest {
            throw 'Response status code does not indicate success: NotFound (Not Found).'
        }

        $row = Get-CloudPCLaunchDetail -Id 'cpc-provisioning' -UserId 'user@contoso.com' -ErrorAction SilentlyContinue

        $row.PSObject.TypeNames | Should -Contain 'WindowsCloudPC.CloudPCLaunchDetail'
        $row.CloudPcId | Should -Be 'cpc-provisioning'
        $row.UserId | Should -Be 'user@contoso.com'
        $row.CloudPcLaunchUrl | Should -BeNullOrEmpty
        $row.WindowsAppLaunchUri | Should -BeNullOrEmpty
        $row.LaunchDetailStatus | Should -Be 'Unavailable'
        $row.ErrorMessage | Should -Match 'NotFound'
    }

    It 'preserves the raw Graph response on Raw' {
        $row = Get-CloudPCLaunchDetail -Id 'cpc-1'
        $row.Raw | Should -Not -BeNullOrEmpty
    }
}
