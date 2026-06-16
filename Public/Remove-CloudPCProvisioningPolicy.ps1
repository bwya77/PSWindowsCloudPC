function Remove-CloudPCProvisioningPolicy {
    <#
    .SYNOPSIS
        Deletes a Windows 365 Cloud PC provisioning policy.

    .DESCRIPTION
        Deletes a Cloud PC provisioning policy by calling Microsoft Graph beta:
        DELETE /deviceManagement/virtualEndpoint/provisioningPolicies/{id}.

        Microsoft Graph cannot delete a provisioning policy that is still in use.
        This cmdlet supports -WhatIf / -Confirm and defaults to ConfirmImpact = 'High'.
        Use -Force to suppress the confirmation prompt in automation.

        Requires the CloudPC.ReadWrite.All scope; the cmdlet automatically
        reauthenticates through Connect-CloudPC if the current Graph session does
        not already have it.

    .PARAMETER Id
        The Cloud PC provisioning policy ID.

    .PARAMETER ProvisioningPolicy
        A WindowsCloudPC.ProvisioningPolicy object returned by Get-CloudPCProvisioningPolicy.

    .PARAMETER Force
        Suppress the confirmation prompt. Equivalent to -Confirm:$false.

    .PARAMETER PassThru
        Emit a WindowsCloudPC.ProvisioningPolicyRemoveResult object describing the outcome.
        By default the cmdlet is silent on success.

    .EXAMPLE
        Remove-CloudPCProvisioningPolicy -Id '96e8ec2e-949c-40ca-a345-100a0035d0d1' -WhatIf

        Previews deleting a provisioning policy by ID.

    .EXAMPLE
        Get-CloudPCProvisioningPolicy -Id '96e8ec2e-949c-40ca-a345-100a0035d0d1' |
            Remove-CloudPCProvisioningPolicy -Force -PassThru

        Deletes a provisioning policy from the pipeline and emits the delete result.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    [OutputType('WindowsCloudPC.ProvisioningPolicyRemoveResult')]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ById')]
        [Alias('ProvisioningPolicyId')]
        [string]$Id,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
        [PSTypeName('WindowsCloudPC.ProvisioningPolicy')]
        [object]$ProvisioningPolicy,

        [switch]$Force,

        [switch]$PassThru
    )

    begin {
        if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = 'None'
        }

        Connect-CloudPC -AdditionalScopes 'CloudPC.ReadWrite.All' | Out-Null
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByObject') {
            $policyId = $ProvisioningPolicy.Id
            $policyName = if ($ProvisioningPolicy.DisplayName) { $ProvisioningPolicy.DisplayName } else { $ProvisioningPolicy.Id }
        }
        else {
            $policyId = $Id
            $policyName = $Id
        }

        if (-not $policyId) {
            Write-Error 'Remove-CloudPCProvisioningPolicy: provisioning policy Id is empty; nothing to delete.'
            return
        }

        $target = "Cloud PC provisioning policy '$policyName' ($policyId)"
        $status = 'WhatIf'
        $errorMessage = $null

        if ($PSCmdlet.ShouldProcess($target, 'Delete provisioning policy')) {
            try {
                $escapedId = [uri]::EscapeDataString($policyId)
                $uri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies/$escapedId"
                Invoke-MgGraphRequest -Method DELETE -Uri $uri | Out-Null
                $status = 'Deleted'
                Write-Verbose "Remove-CloudPCProvisioningPolicy: deleted $target"
            }
            catch {
                $status = 'Failed'
                $errorMessage = if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                    $_.ErrorDetails.Message
                }
                else {
                    $_.Exception.Message
                }
                Write-Error -Message "Remove-CloudPCProvisioningPolicy: delete failed for $target. $errorMessage" -Exception $_.Exception
            }
        }

        if ($PassThru) {
            [pscustomobject]@{
                PSTypeName   = 'WindowsCloudPC.ProvisioningPolicyRemoveResult'
                Id           = $policyId
                DisplayName  = $policyName
                Status       = $status
                RequestedAt  = [datetime]::Now
                ErrorMessage = $errorMessage
            }
        }
    }

    end { }
}

