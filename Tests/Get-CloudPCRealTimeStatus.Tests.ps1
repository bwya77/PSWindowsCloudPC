BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsCloudPC.psd1'
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module WindowsCloudPC | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CloudPCRealTimeStatus' {

    Context 'response handling' {

        It 'parses a populated single-row report' {
            $json = @{
                TotalRowCount = 1
                Schema = @(
                    @{ Column = 'ManagedDeviceName';   PropertyType = 'String' }
                    @{ Column = 'CloudPcId';           PropertyType = 'String' }
                    @{ Column = 'DaysSinceLastSignIn'; PropertyType = 'Int64' }
                    @{ Column = 'SignInStatus';        PropertyType = 'String' }
                    @{ Column = 'LastActiveTime';      PropertyType = 'DateTime' }
                )
                Values = @(, @('CFD-x', 'id-x', 0, 'SignedIn', '2026-06-15T19:00:00'))
            } | ConvertTo-Json -Depth 5 -Compress

            Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest -MockWith {
                Set-Content -LiteralPath $OutputFilePath -Value $json -NoNewline
            }

            $r = & (Get-Module WindowsCloudPC) { Get-CloudPCRealTimeStatus -CloudPcId 'id-x' }
            $r.SignInStatus | Should -Be 'SignedIn'
            $r.DaysSinceLastSignIn | Should -Be 0
            $r.LastActiveTime | Should -BeOfType [datetime]
        }

        It 'synthesizes a NotSignedIn row when TotalRowCount is 0 (never signed in)' {
            $json = '{"TotalRowCount":0,"Schema":[{"Column":"ManagedDeviceName","PropertyType":"String"},{"Column":"CloudPcId","PropertyType":"String"},{"Column":"DaysSinceLastSignIn","PropertyType":"Int64"},{"Column":"SignInStatus","PropertyType":"String"},{"Column":"LastActiveTime","PropertyType":"DateTime"}],"Values":[]}'

            Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest -MockWith {
                Set-Content -LiteralPath $OutputFilePath -Value $json -NoNewline
            }

            $r = & (Get-Module WindowsCloudPC) { Get-CloudPCRealTimeStatus -CloudPcId 'never-used' }
            $r | Should -Not -BeNullOrEmpty
            $r.SignInStatus | Should -Be 'NotSignedIn'
            $r.CloudPcId | Should -Be 'never-used'
            $r.LastActiveTime | Should -BeNullOrEmpty
        }

        It 'returns null when Graph throws' {
            Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest -MockWith { throw 'boom' }

            $r = & (Get-Module WindowsCloudPC) { Get-CloudPCRealTimeStatus -CloudPcId 'bad' }
            $r | Should -BeNullOrEmpty
        }

        It 'cleans up the temp file even when parsing fails' {
            $before = (Get-ChildItem $env:TEMP -Filter 'wcpc-rtrcs-*.json' -ErrorAction SilentlyContinue).Count

            Mock -ModuleName WindowsCloudPC Invoke-MgGraphRequest -MockWith {
                Set-Content -LiteralPath $OutputFilePath -Value 'not-json' -NoNewline
            }

            & (Get-Module WindowsCloudPC) { Get-CloudPCRealTimeStatus -CloudPcId 'junk' } | Out-Null

            (Get-ChildItem $env:TEMP -Filter 'wcpc-rtrcs-*.json' -ErrorAction SilentlyContinue).Count |
                Should -Be $before
        }
    }
}
