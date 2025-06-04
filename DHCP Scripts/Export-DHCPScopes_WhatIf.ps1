<#
.SYNOPSIS
    Check DHCP scopes for bad DNS IPs and show what would be replaced.

.DESCRIPTION
    This script audits DHCP scopes across multiple servers for known bad DNS entries and suggests replacements.
    It does NOT change anything, only exports WhatIf information.

.NOTES
    Script Name    : Export-DHCPScopes-Information.ps1
    Version        : 1.0
    Author         : ChatGPT
    Approved By    : [Approver's Name]
    Date           : [Today's Date]
    Purpose        : Export DHCP scope and DNS information for documentation or review.

.PREREQUISITES
    - DHCP Server role installed on the servers.
    - Appropriate permissions to query DHCP servers.
    - DHCP Server PowerShell module available.

#>

# Start of Script
$DhcpServerList = "C:\Temp\Servers.txt"
$OutputPath = "C:\Temp\DHCP_DNS_WhatIfReport.csv"

$BadIPs  = @('0.0.0.0', '0.0.0.0', '0.0.0.0', '0.0.0.0', '0.0.0.0')
$GoodIPs = @('0.0.0.0', '0.0.0.0', '10.0.0.0')

$Results = @()
$Servers = Get-Content -Path $DhcpServerList

foreach ($Server in $Servers) {
    try {
        Write-Host "Checking server: $Server" -ForegroundColor Cyan
        $Scopes = Get-DhcpServerv4Scope -ComputerName $Server

        foreach ($Scope in $Scopes) {
            $Options = Get-DhcpServerv4OptionValue -ScopeId $Scope.ScopeId -ComputerName $Server -ErrorAction SilentlyContinue
            $DnsServers = ($Options | Where-Object {$_.OptionId -eq 6}).Value

            if ($DnsServers) {
                $Primary = $DnsServers[0]
                $Secondary = if ($DnsServers.Count -gt 1) { $DnsServers[1] } else { $null }

                $PrimaryNeedsChange = $BadIPs -contains $Primary
                $SecondaryNeedsChange = $BadIPs -contains $Secondary

                if ($PrimaryNeedsChange -or $SecondaryNeedsChange) {
                    $Results += [PSCustomObject]@{
                        DHCPServerName = $Server
                        ScopeID        = $Scope.ScopeId
                        ScopeName      = $Scope.Name
                        CurrentPrimary = $Primary
                        CurrentSecondary = $Secondary
                        SuggestedPrimary = if ($PrimaryNeedsChange) { $GoodIPs[0] } else { $Primary }
                        SuggestedSecondary = if ($SecondaryNeedsChange) { $GoodIPs[1] } else { $Secondary }
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to process $Server. Error: $_"
    }
}

$Results | Export-Csv -Path $OutputPath -NoTypeInformation -Force

Write-Host "WhatIf report exported to $OutputPath" -ForegroundColor Green
# End of Script
