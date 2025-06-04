<#
.SYNOPSIS
    Update DHCP scopes to replace bad DNS IPs with good ones.

.DESCRIPTION
    This script connects to DHCP servers and modifies DHCP scopes if Primary or Secondary DNS has bad IPs,
    replacing them with predefined good DNS IPs.

.NOTES
    Script Name    : Replace-DHCPScopes-DNS.ps1
    Version        : 1.0
    Author         : Jonathan Preetham
    Approved By    : [Approver's Name]
    Date           : [Today's Date]
    Purpose        : Replace bad DNS entries in DHCP scopes with correct DNS servers for consistency and reliability.

.PREREQUISITES
    - DHCP Server role installed on the servers.
    - Appropriate permissions to modify DHCP servers.
    - DHCP Server PowerShell module available.

#>

# Start of Script
$DhcpServerList = "C:\Scripts\Servers.txt"

$BadIPs  = @('0.0.0.0', '0.0.0.0', '0.0.0.0', '10.0.0.0', '172.23.128.99')
$GoodIPs = @('0.0.0.0', '0.0.0.0', '0.0.0.0')

$Servers = Get-Content -Path $DhcpServerList

foreach ($Server in $Servers) {
    try {
        Write-Host "Modifying server: $Server" -ForegroundColor Cyan
        $Scopes = Get-DhcpServerv4Scope -ComputerName $Server

        foreach ($Scope in $Scopes) {
            $Options = Get-DhcpServerv4OptionValue -ScopeId $Scope.ScopeId -ComputerName $Server -ErrorAction SilentlyContinue
            $DnsServers = ($Options | Where-Object {$_.OptionId -eq 6}).Value

            if ($DnsServers) {
                $Primary = $DnsServers[0]
                $Secondary = if ($DnsServers.Count -gt 1) { $DnsServers[1] } else { $null }
                $Updated = $false

                if ($BadIPs -contains $Primary) {
                    $Primary = $GoodIPs[0]
                    $Updated = $true
                }
                if ($BadIPs -contains $Secondary) {
                    $Secondary = $GoodIPs[1]
                    $Updated = $true
                }

                if ($Updated) {
                    Remove-DhcpServerv4OptionValue -ScopeId $Scope.ScopeId -OptionId 6 -ComputerName $Server -Confirm:$false
                    Set-DhcpServerv4OptionValue -ScopeId $Scope.ScopeId -DnsServer $Primary, $Secondary -ComputerName $Server
                    Write-Host "Updated Scope $($Scope.ScopeId) on $Server" -ForegroundColor Yellow
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to modify $Server. Error: $_"
    }
}

Write-Host "DNS update completed." -ForegroundColor Green
# End of Script
